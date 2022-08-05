/*
    BSD 3-Clause License
    
    Copyright (c) 2022, Kyle Schmid, Tondro Consulting, LLC
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright notice, this
      list of conditions and the following disclaimer.
    
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    
    * Neither the name of the copyright holder nor the names of its
      contributors may be used to endorse or promote products derived from
      this software without specific prior written permission.
    
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
	OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
public class ObjectMergeValidator {
	
    // Get global describe once to save CPU time
    private static final Map<String, Schema.SObjectType> GLOBAL_DESCRIBE = Schema.getGlobalDescribe();
    
    // Record Type ID for Child Object Merge Handlers
    private static final Id CHILD_HANDLER_RT_ID = Schema.SObjectType.Object_Merge_Handler__c.getRecordTypeInfosByDeveloperName().get('Child_Handler').getRecordTypeId();
    
    // Error messages
    private static final String INVALID_OBJECT_ERROR = 'This Object Merge Handler is invalid because the SObject does not exist. Check to make sure the API name is valid.';
    private static final String INVALID_LOOKUP_FIELD_ERROR = 'This Object Merge Handler is invalid because the Object Lookup Field does not exist on the object. Check to make sure the API name is valid.';
    private static final String INVALID_LOOKUP_ERROR = 'This Object Merge Handler is invalid because the Object Lookup Field is not a field that references the parent object.';
    private static final String INVALID_FIELD_ERROR = 'This Object Merge Field is invalid because the field does not exist on the parent object. Check to make sure the API name is valid.';
    private static final String INVALID_KEEP_MOST_RECENT_VALUE_FIELD_ERROR = 'This Object Merge Field is invalid because the Keep Most Recent Value checkbox is checked but Field History Tracking is not enabled.';
    
    // Method to ensure the Object Merge Handlers are valid
    public static void validateObjectMergeHandlers(List<Object_Merge_Handler__c> objectMergeHandlers) {
		
        Set<Id> parentHandlerIds = new Set<Id>(); // Set of parent object merge handler IDs from child handlers
        List<Object_Merge_Handler__c> childHandlers = new List<Object_Merge_Handler__c>(); // Set of child object merge handlers
        
        // Loop through all handlers and add error to any active handlers
        // that have an invalid object API name or invalid lookup field API name
        for (Object_Merge_Handler__c h:objectMergeHandlers) {
            
            // Only run on active handlers
            if (h.Active__c) {
                
                // Check if object API name is valid and add error if not
                if (!GLOBAL_DESCRIBE.containsKey(h.Name)) {
                    
                	h.addError(INVALID_OBJECT_ERROR); // Add error to handler
                    
                } else if (h.RecordTypeId == CHILD_HANDLER_RT_ID && h.Parent_Handler__c != null) {
                    
                    // Check if lookup field API name is valid and add error if not
                    if (!GLOBAL_DESCRIBE.get(h.Name).getDescribe().fields.getMap().containsKey(h.Object_Lookup_Field_API_Name__c)) {
                        
                        h.addError(INVALID_LOOKUP_FIELD_ERROR); // Add error to handler
                        
                    } else {
                        
                        parentHandlerIds.add(h.Parent_Handler__c); // Add parent handler ID to set
                        childHandlers.add(h); // Add handler to list of child handlers
                    }
                }
            }
        }
        
        // Ensure all child handlers have valid lookup field
        if (!childHandlers.isEmpty()) {
            
            // Get map of parent handlers
            Map<Id, Object_Merge_Handler__c> parentHandlers = new Map<Id, Object_Merge_Handler__c>([SELECT Id, Name FROM Object_Merge_Handler__c WHERE Id IN :parentHandlerIds]);
            
            // Loop over child handlers and ensure lookup field references parent object type
            for (Object_Merge_Handler__c h:childHandlers) {
                
                // Get object type of parent handler
                Schema.SObjectType parentObject = GLOBAL_DESCRIBE.get(parentHandlers.get(h.Parent_Handler__c).Name);
                
                // Get list of object types the lookup field references
                List<Schema.SObjectType> referenceObjects = GLOBAL_DESCRIBE.get(h.Name).getDescribe().fields.getMap().get(h.Object_Lookup_Field_API_Name__c).getDescribe().getReferenceTo();
                
                // Add error if parent object type is null, list of object types referenced is null,
                // or list of object types references does not contain parent object type
                if (parentObject == null || referenceObjects == null || !(new Set<Schema.SObjectType>(referenceObjects)).contains(parentObject))
                    h.addError(INVALID_LOOKUP_ERROR);
            }
        }
    }
    
    // Method to ensure the Object Merge Fields are valid
    public static void validateObjectMergeFields(List<Object_Merge_Field__c> objectMergeFields) {
		
        Set<Id> handlerIds = new Set<Id>(); // Set of handler IDs for active Object Merge Fields
        List<Object_Merge_Field__c> activeFields = new List<Object_Merge_Field__c>(); // List of active Object Merge Fields
        
        // Loop over list and get list of active Object Merge Fields and set of handler ids for those fields
        for (Object_Merge_Field__c f:objectMergeFields) {
            
            // Only run on active fields
            if (f.Active__c) {
                
            	handlerIds.add(f.Object_Merge_Handler__c); // Add handler ID to set
                activeFields.add(f); // Add field to list
            }
        }
		
        // Ensure each active field is valid
        if (!activeFields.isEmpty()) {
            
            Map<Id, Map<String, Schema.SObjectField>> handlerFieldMap = new Map<Id, Map<String, Schema.SObjectField>>(); // Map of fields for object by Object Merge Handler ID
            
            // Query Object Merge Handlers and populate map from describe information
            for (Object_Merge_Handler__c h:[SELECT Id, Name FROM Object_Merge_Handler__c WHERE Id IN :handlerIds])
                if (GLOBAL_DESCRIBE.containsKey(h.Name))
                    handlerFieldMap.put(h.Id, GLOBAL_DESCRIBE.get(h.Name).getDescribe().fields.getMap());
            
            // Loop through all active fields, check to see if field API name is valid and add error if not
            for (Object_Merge_Field__c f:activeFields)
                if (!handlerFieldMap.containsKey(f.Object_Merge_Handler__c) || !handlerFieldMap.get(f.Object_Merge_Handler__c).containsKey(f.Name))
                    f.addError(INVALID_FIELD_ERROR);
        }
    }
}