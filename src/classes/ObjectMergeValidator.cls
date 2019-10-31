/*
    BSD 3-Clause License
    
    Copyright (c) 2019, Kyle Schmid, Huron Consulting Group
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
	
    private static final Map<String, Schema.SObjectType> GLOBAL_DESCRIBE = Schema.getGlobalDescribe();
    
    // Checks to make sure name of handler is in the org
    public static void validateObjectMergeHandlers(List<Object_Merge_Handler__c> objectMergeHandlers) {
		
        // Loop through all handlers to find which aren't valid based on their objects absence in the org
        for (Object_Merge_Handler__c omh:objectMergeHandlers)
            if (!GLOBAL_DESCRIBE.containsKey(omh.Name.toLowerCase()))
                omh.addError('This Object Merge handler is invalid because the sObject does not exist. Check to make sure the API name is valid.');
    }

    // Ensures that the name of the field handler is on the parent object
    public static void validateFieldHandlers(List<Object_Merge_Field__c> objectMergeFields) {
		
        // Collect set of handler ids
        Set<Id> handlerIds = new Set<Id>();
        for (Object_Merge_Field__c omf:objectMergeFields)
            handlerIds.add(omf.Object_Merge_Handler__c);
		
        // Query for handlers to get object names
        Map<Id, Object_Merge_Handler__c> handlers = new Map<Id, Object_Merge_Handler__c>([SELECT Id, Name FROM Object_Merge_Handler__c WHERE Id IN :handlerIds]);
		
        // Loop through all fields to find which aren't valid based on their absence on the parent object
        for (Object_Merge_Field__c omf:objectMergeFields)
            if (!GLOBAL_DESCRIBE.get(handlers.get(omf.Object_Merge_Handler__c).Name.toLowerCase()).getDescribe().fields.getMap().keySet().contains(omf.Name.toLowerCase()))
                omf.addError( 'This Object Merge Field is invalid because the field does on the handler\'s object. Check to make sure the API name is valid.' );
    }
}