/*
    BSD 3-Clause License
    
    Copyright (c) 2025, Kyle Schmid, Tondro Consulting, LLC
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
public without sharing class ObjectMergeUtility {
	
    // Get global describe once to save CPU time
    private static final Map<String, SObjectType> GLOBAL_DESCRIBE = Schema.getGlobalDescribe();
    
    // Static Boolean that tracks if organization is portal enabled
    public static Boolean portalEnabled {
        get {
            
            if (portalEnabled == null) {
                
                Map<String, Schema.SObjectField> userFieldMap = User.getSObjectType().getDescribe().fields.getMap(); // Get user field map from describe
                portalEnabled = userFieldMap.containsKey('ContactId') && userFieldMap.containsKey('IsPortalEnabled'); // Determine if organization is portal enabled
            }
            
            return portalEnabled;
        }
        
        private set;
    }
    
    // Static map of handler wrappers
    private static Map<Schema.SObjectType, ObjectMergeHandlerWrapper> handlers {
        get {
            
            // Populate map if null
            if (handlers == null) {
                
                handlers = new Map<Schema.SObjectType, ObjectMergeHandlerWrapper>(); // Instantiate map
				
                // Query parent and child merge handlers
                List<Object_Merge_Handler__c> objectMergeHandlers = [SELECT Id, Name, Merge_All_Fields__c, (SELECT Id, Name, Object_Lookup_Field_API_Name__c, Standard_Action__c, Merge_Action__c, Clone_Reparented_Victim__c, Merge_All_Fields__c FROM Object_Merge_Handlers__r WHERE Active__c = true ORDER BY Order_of_Execution__c ASC NULLS LAST) FROM Object_Merge_Handler__c WHERE RecordType.DeveloperName = 'Parent_Handler' AND Active__c = true];
                
                // Map of fields by handler ID
                Map<Id, List<Object_Merge_Field__c>> fieldMap = new Map<Id, List<Object_Merge_Field__c>>();
                
                // Loop over merge handlers and populate fieldMap
                for (Object_Merge_Handler__c h:objectMergeHandlers) {
                    
                    fieldMap.put(h.Id, new List<Object_Merge_Field__c>()); // Handle parent fields
					
                    // Handle child fields
                    for (Object_Merge_Handler__c ch:h.Object_Merge_Handlers__r)
                        fieldMap.put(ch.Id, new List<Object_Merge_Field__c>());
                }
				
                // Query fields and put in fieldMap
                for (Object_Merge_Field__c f:[SELECT Id, Object_Merge_Handler__c, Name, Use_for_Matching__c, Keep_Least_Recent_Value__c, Keep_Most_Recent_Value__c, Keep_Null_Value__c, Treat_False_as_Null__c FROM Object_Merge_Field__c WHERE Active__c = true AND Object_Merge_Handler__c IN :fieldMap.keySet()])
                    fieldMap.get(f.Object_Merge_Handler__c).add(f);
				
                // Loop over handlers and get wrapper for each
                for (Object_Merge_Handler__c h:objectMergeHandlers) {
                    
                    // Get new handler wrapper
                    ObjectMergeHandlerWrapper handler = new ObjectMergeHandlerWrapper(h, h.Object_Merge_Handlers__r, fieldMap);
                    
                    // Add handler wrapper to map if valid
                    if (handler.isValid)
                        handlers.put(handler.token, handler);
                }
            }
			
            return handlers; // Return map
        }
		
        private set;
    }
    
    // Method called by trigger to merge records referenced in pairs
    public static void mergeRecords(List<Object_Merge_Pair__c> pairs, Boolean isUpdate) {
        
        mergeRecords(pairs, null, isUpdate);
    }
    
    // Method called by queueable class after user deactivation to merge records referenced by pairs and update owners
    public static void mergeRecordsWithOwners(List<Object_Merge_Pair__c> pairs, Map<Id, Id> ownerIdMap) {
        
        mergeRecords(pairs, ownerIdMap, true);
    }
    
    // Single method to merge records referenced by pairs
    private static void mergeRecords(List<Object_Merge_Pair__c> pairs, Map<Id, Id> ownerIdMap, Boolean isUpdate) {
        
        // Map of pairs grouped by object type
        Map<Schema.SObjectType, List<Object_Merge_Pair__c>> pairMap = new Map<Schema.SObjectType, List<Object_Merge_Pair__c>>();
        
        // Loop over pairs, instantiate fields, validate and add IDs to map
        for (Object_Merge_Pair__c p:pairs) {
            
            // Skip if already merged
            if (isUpdate && p.Status__c == 'Merged')
                continue;
            
            p.Merge_Date__c = System.now(); // Set merge date to now
            
            // Default error reason to null and exception fields to null
            p.Error_Reason__c = null;
            p.Apex_Exception_Line_Number__c = null;
            p.Apex_Exception_Message__c = null;
            p.Apex_Exception_Stack_Trace__c = null;
            p.Apex_Exception_Type__c = null;
            p.DML_Exception_Field_Names__c = null;
            p.DML_Exception_IDs__c = null;
            p.DML_Exception_Messages__c = null;
            p.DML_Exception_Types__c = null;
            
            // Check for valid status (Blank if insert or Retry if update)
            if ((!isUpdate && String.isNotBlank(p.Status__c)) || (isUpdate && p.Status__c != 'Retry')) {
                
                addError(p, 'Invalid status');
                continue;
            }
            
            p.Status__c = null; // Default status to null
            
            // Check for valid IDs and add pair to map
            try {
                
                // Get object type of Master ID
                Schema.SObjectType token = Id.valueOf(p.Master_ID__c).getSObjectType();
                
                // Check to make Master ID and Victim ID have the same object type
                if (token != Id.valueOf(p.Victim_ID__c).getSObjectType())
                    throw new ObjectMergeException();
                
                // Check to make sure we have a handler for this object type
                if (handlers.containsKey(token)) {
                    
                    // Add object type to map if not already there
                    if (!pairMap.containsKey(token))
                        pairMap.put(token, new List<Object_Merge_Pair__c>());
                    
                    pairMap.get(token).add(p); // Add pair to map for its object type
                    
                } else {
                    
                    addError(p, 'Object Merge Handler not found'); // Add error to pair if no handler found
                }
                
            } catch (Exception e) {
                
                addError(p, 'Invalid Master/Victim ID pair'); // Add error to pair if IDs not valid or don't match
            }
        }
        
        // Loop over object types and merge pairs one object type at a time
        for (Schema.SObjectType token:pairMap.keySet()) {
            
            // Perform the merge
            handlers.get(token).doMerge(pairMap.get(token), ownerIdMap);
        }
    }
    
    // Adds an error to a list of pairs
    private static void addError(List<Object_Merge_Pair__c> pairs, String reason, Exception except) {
        
        ObjectMergeError error = new ObjectMergeError(reason, except);
        
        // Loop over pairs and apply error to each
        for (Object_Merge_Pair__c pair:pairs)
            error.applyError(pair);
    }
    
    // Adds an error to a pair
    private static void addError(Object_Merge_Pair__c pair, String reason) {
        
        addError(pair, reason, null); // Call method with null exception
    }
    
    // Adds an error to a pair
    private static void addError(Object_Merge_Pair__c pair, String reason, Exception except) {
        
        (new ObjectMergeError(reason, except)).applyError(pair); // Instantiate error and apply to pair
    }
    
    // Wrapper class for an error
    private class ObjectMergeError {
        
        private String reason; // Error reason
        private Integer lineNumber; // Line number from base exception
        private String message; // Message from base exception
        private String stackTrace; // Stack trace from base exception
        private String typeName; // Type name from base exception
        private String fieldNames; // Field names from DMLException or Database Errors
        private String ids; // IDs from DMLException or Database Errors
        private String dmlMessages; // Messages from DMLException or Database Errors
        private String dmlTypes; // Exception types from DMLException or Database Errors
        
        // Constructor
        private ObjectMergeError(String reason, Exception except) {
            
            this.reason = reason; // Set reason
            
            // Process exception information if non-null
        	if (except != null) {
            	
                // Lists of DMLException/Database Error information (one value for each failed row)
                List<String> fieldNames = new List<String>();
                List<String> ids = new List<String>();
                List<String> messages = new List<String>();
                List<String> types = new List<String>();
                
                // Get DMLException/Database Error information if exception is a DMLException or ObjectMergeException
                if (except instanceof DMLException) {
                    
                    DMLException dmlException = (DMLException)except; // Cast exception as DMLException
                    
                    // Loop over failed rows and add exception information to lists
                    for (Integer i = 0; i < dmlException.getNumDml(); i++) {
                        
                        fieldNames.add(String.valueOf(dmlException.getDmlFieldNames(i)));
                        ids.add(dmlException.getDmlId(i));
                        messages.add(dmlException.getDmlMessage(i));
                        types.add(dmlException.getDmlType(i).name());
                    }
                    
                } else if (except instanceof ObjectMergeException) {
                    
                    ObjectMergeException objectMergeException = (ObjectMergeException)except; // Cast exception as ObjectMergeException
                    
                    // Process database errors if non-null
                    if (objectMergeException.databaseErrorIds != null) {
                        
                        ids.addAll(objectMergeException.databaseErrorIds); // Add all IDs to list
                        
                        // Loop over errors and add to lists
                        for (Database.Error error:objectMergeException.databaseErrors) {
                            
                            fieldNames.add(String.valueOf(error.getFields()));
                            messages.add(error.getMessage());
                            types.add(error.getStatusCode().name());
                        }
                    }
                }
                
                // Set exception information
                this.lineNumber = except.getLineNumber();
                this.message = except.getMessage();
                this.stackTrace = except.getStackTraceString();
                this.typeName = except.getTypeName();
                this.fieldNames = String.join(fieldNames, '\n');
                this.ids = String.join(ids, '\n');
                this.dmlMessages = String.join(messages, '\n');
                this.dmlTypes = String.join(types, '\n');
            }
        }
        
        // Method to apply error information to Object Merge Pair
        private void applyError(Object_Merge_Pair__c pair) {
            
            pair.Status__c = 'Error';
            pair.Error_Reason__c = this.reason;
            pair.Apex_Exception_Line_Number__c = this.lineNumber;
            pair.Apex_Exception_Message__c = this.message;
            pair.Apex_Exception_Stack_Trace__c = this.stackTrace;
            pair.Apex_Exception_Type__c = this.typeName;
            pair.DML_Exception_Field_Names__c = this.fieldNames;
            pair.DML_Exception_IDs__c = this.ids;
            pair.DML_Exception_Messages__c = this.dmlMessages;
            pair.DML_Exception_Types__c = this.dmlTypes;
        }
    }
	
    // Wrapper class for an object merge handler
    private class ObjectMergeHandlerWrapper {
        
        private Schema.SObjectType token; // Object type
        private String name; // Object API name
        private String historyObjectName; // API name of the field history tracking object for this object
        private String historyObjectParentFieldName; // API name of the field on the field history tracking object that references this object
        private Map<String, Schema.SObjectField> fieldMap; // Map of object fields
        private List<ObjectMergeFieldWrapper> fields; // List of field wrappers
        private List<ObjectMergeHandlerWrapper> childHandlers; // List of child handler wrappers
        private ObjectMergeFieldWrapper lookupField; // Field wrapper representing lookup field (used in child handlers)
        private List<ObjectMergeFieldWrapper> matchingFields; // List of field wrappers to match on (used in child handlers)
        private Set<String> keepLeastRecentValueFields; // Set of field names to keep least recent field value for
        private Set<String> keepMostRecentValueFields; // Set of field names to keep most recent field value for
        private Set<String> queryFields; // Set of fields to query
        
        private Id handlerId; // ID of Object Merge Handler record
        private String standardAction; // Standard Action from Object Merge Handler record
        private String mergeAction; // Merge Action from Object Merge Handler record
        private Boolean cloneReparentedVictim; // Clone Reparented Victim from Object Merge Pair record
        
        private Boolean isValid; // Boolean indicating this is a valid handler wrapper
        private Boolean handleUser; // Boolean indicating this is a parent handler for Contact with a child handler for user
        private Boolean hasOwner; // Boolean indicating this object has an OwnerId field
        private Boolean checkFieldHistory; // Boolean indicating this object needs field history checked during a merge
        
        // Constructor for parent handler
        private ObjectMergeHandlerWrapper(Object_Merge_Handler__c objectMergeHandler, List<Object_Merge_Handler__c> childObjectMergeHandlers, Map<Id, List<Object_Merge_Field__c>> fieldMap) {
            
            // Initialize handler
            init(objectMergeHandler, fieldMap.get(objectMergeHandler.Id));
			
            this.isValid = this.token != null; // Handler is valid if object is valid
			
            // Set additional attributes if handler is valid
            if (this.isValid) {
				
                Boolean isContact = this.token == Contact.getSObjectType(); // Track whether this is a Contact parent handler
                Schema.SObjectType userToken = User.getSObjectType(); // Grab User object type
                this.handleUser = false; // Default handle user to false
                this.childHandlers = new List<ObjectMergeHandlerWrapper>(); // Instantiate list of child handlers
                
                // Loop over child Object Merge Handlers, instantiate and add child handler wrappers to list
                for (Object_Merge_Handler__c childObjectMergeHandler:childObjectMergeHandlers) {
					
                    // Instantiate child handler
                    ObjectMergeHandlerWrapper childHandler = new ObjectMergeHandlerWrapper(childObjectMergeHandler, fieldMap.get(childObjectMergeHandler.Id), this.token);
					
                    // Check to see if child handler is valid
                    if (childHandler.isValid) {
                        
                        // Set handleUser if this is a child handler for users. Otherwise, add to child handler list
                        if (isContact && childHandler.token == userToken && childHandler.lookupField.name == 'ContactId' && portalEnabled)
                            this.handleUser = true;
                        else
                        	this.childHandlers.add(childHandler);
                    }
                }
            }
        }
        
        // Constructor for child handler
        private ObjectMergeHandlerWrapper(Object_Merge_Handler__c objectMergeHandler, List<Object_Merge_Field__c> objectMergeFields, Schema.SObjectType parentToken) {
            
            // Initialize handler
            init(objectMergeHandler, objectMergeFields);
			
            // Check if object is valid and contains lookup field
            if (this.token != null && this.fieldMap.containsKey(objectMergeHandler.Object_Lookup_Field_API_Name__c)) {
				
                // Copy field values from Object Merge Handler record
                this.standardAction = objectMergeHandler.Standard_Action__c;
                this.mergeAction = objectMergeHandler.Merge_Action__c;
                this.cloneReparentedVictim = objectMergeHandler.Clone_Reparented_Victim__c;
                
                // Set lookup field wrapper and add lookup field name to query field set
                this.lookupField = new ObjectMergeFieldWrapper(this.fieldMap.get(objectMergeHandler.Object_Lookup_Field_API_Name__c));
                this.queryFields.add(this.lookupField.name);
                
                // Valid handler if lookup field is reference field to parent object type
                this.isValid = this.lookupField.referenceObjects != null && (new Set<Schema.SObjectType>(this.lookupField.referenceObjects)).contains(parentToken);
            }
        }
        
        // Init method to handle actions common among parent and child handlers
        private void init(Object_Merge_Handler__c objectMergeHandler, List<Object_Merge_Field__c> objectMergeFields) {
			
            this.isValid = false; // Default isValid to false
            this.token = GLOBAL_DESCRIBE.get(objectMergeHandler.Name); // Grab object type based on object name
            this.handlerId = objectMergeHandler.Id; // Set handlerId
            
            // Make sure object type is valid
            if (this.token != null) {
                
                Schema.DescribeSObjectResult describe = this.token.getDescribe(); // Grab describe
                
                this.name = describe.getName(); // Set name to official name from describe
                this.historyObjectName = (describe.isCustom() ? this.name.substringBeforeLast('c') : this.name) + (this.token == Opportunity.getSObjectType() ? 'Field' : '') + 'History'; // Set history object name
                this.historyObjectParentFieldName = (describe.isCustom() ? 'Parent' : this.name) + 'Id'; // Set history object parent field name
                this.fieldMap = describe.fields.getMap(); // Set fieldMap
                this.fields = new List<ObjectMergeFieldWrapper>(); // Instantiate list of field wrappers
                this.matchingFields = new List<ObjectMergeFieldWrapper>(); // Instantiate list of matching field wrappers
                this.keepLeastRecentValueFields = new Set<String>(); // Instantiate set of keep least recent value field names
                this.keepMostRecentValueFields = new Set<String>(); // Instantiate set of keep most recent value field names
                this.hasOwner = this.fieldMap.containsKey('OwnerId'); // See if object has OwnerId
                this.checkFieldHistory = GLOBAL_DESCRIBE.containsKey(this.historyObjectName); // See if object has field history tracking enabled
                this.queryFields = new Set<String>{'id'}; // Instantiate queryFields with Id
				
                // Add CreatedDate and LastModifiedDate to query fields set if object has them
                if (this.fieldMap.containsKey('CreatedDate') && this.fieldMap.containsKey('LastModifiedDate')) {
                    
                    this.queryFields.add('createddate');
                    this.queryFields.add('lastmodifieddate');
                }
                
                // Add OwnerId to query fields set if object has it
                if (this.hasOwner)
                    this.queryFields.add('ownerid');
				
                Set<Schema.SObjectField> objectMergeFieldTokens = new Set<Schema.SObjectField>(); // Set of field tokens handled by Object Merge Field records
                
                // Loop over object merge fields and add valid fields to field wrapper list
                for (Object_Merge_Field__c objectMergeField:objectMergeFields) {
                    
                    // Check to make sure this is a valid field
                    if (this.fieldMap.containsKey(objectMergeField.Name)) {
                        
                        // Instantiate field wrapper
                        ObjectMergeFieldWrapper field = new ObjectMergeFieldWrapper(this.fieldMap.get(objectMergeField.Name), objectMergeField.Use_for_Matching__c, objectMergeField.Keep_Least_Recent_Value__c, objectMergeField.Keep_Most_Recent_Value__c, objectMergeField.Keep_Null_Value__c, objectMergeField.Treat_False_as_Null__c);
                        
                        objectMergeFieldTokens.add(field.token); // Add token to set
                        this.fields.add(field); // Add field to field wrapper list
                        this.queryFields.add(field.name); // Add field to query fields set
                        
                        // Add field to matchingFields list if it should be used to match
                        if (field.useForMatching)
                            this.matchingFields.add(field);
                        
                        // Add field name to keepLeastRecentValueFields if keep least recent value is set or keepMostRecentValueFields set if keep most recent value is set
                        if (field.keepLeastRecentValue)
                            this.keepLeastRecentValueFields.add(field.name);
                        else if (field.keepMostRecentValue)
                            this.keepMostRecentValueFields.add(field.name);
                    }
                }
                
                // Add all updateable fields for object to field list if Merge All Fields is true
                if (objectMergeHandler.Merge_All_Fields__c) {
                    
                    // Loop over all fields for object
                    for (Schema.SObjectField token:this.fieldMap.values()) {
                        
                        // Check to see if field is already handled by an Object Merge Field
                        if (!objectMergeFieldTokens.contains(token)) {
                            
                        	ObjectMergeFieldWrapper field = new ObjectMergeFieldWrapper(token); // Instantiate field wrapper
                            
                            // Check to see if field is updateable
                            if (field.describe.isUpdateable()) {
                                
                                this.fields.add(field); // Add field to field wrapper list
                                this.queryFields.add(field.name); // Add field to query fields set
                            }
                        }
                    }
                }
                
                this.checkFieldHistory &= (!this.keepLeastRecentValueFields.isEmpty() || !this.keepMostRecentValueFields.isEmpty()); // Only check field history if at least one field has keep least or most recent value set
            }
        }
        
        // Method to perform merge of a list of pairs of the same object type    
        private void doMerge(List<Object_Merge_Pair__c> pairs, Map<Id, Id> ownerIdMap) {
            
            // Get pairs to merge now from list (filter-out victim Contacts with active users)
            List<Object_Merge_Pair__c> pairsToMerge = getPairsToMerge(pairs);
            
            // Exit if no pairs to merge (processing asynchronously)
            if (pairsToMerge.isEmpty())
                return;
            
            Set<Id> parentIds = new Set<Id>(); // Set of parent IDs
            
            // Loop over pairs and get set of parent record IDs
            for (Object_Merge_Pair__c p:pairsToMerge) {
                
                parentIds.add(Id.valueOf(p.Master_ID__c));
                parentIds.add(Id.valueOf(p.Victim_ID__c));
            }
            
            Map<Id, SObject> parents = getParentRecords(parentIds); // Query for parent records
            Map<Id, Map<String, SObject>> parentFieldHistory = queryFieldHistory(parentIds); // Query for parent field history
            Map<Id, Map<Id, List<SObject>>> children = getChildRecords(parentIds); // Query for child records
            Map<Id, Map<Id, Map<String, SObject>>> childFieldHistory = getChildFieldHistory(children); // Query for child field history
            ObjectMergeDMLWrapper dmlWrapper = new ObjectMergeDMLWrapper(this.childHandlers); // Instantiate DML wrapper
            
            // Loop over pairs and merge
            for (Object_Merge_Pair__c p:pairsToMerge) {
                
                SObject master = parents.get(Id.valueOf(p.Master_ID__c)); // Get master from map
                SObject victim = parents.get(Id.valueOf(p.Victim_ID__c)); // Get victim from map
                
                // Merge if we found both master and victim. Add error if not.
                if (master != null && victim != null)
                    mergeRecords(master, victim, parentFieldHistory.get(master.Id), parentFieldHistory.get(victim.Id), children, childFieldHistory, dmlWrapper, ownerIdMap); // Merge records
                else
                    addError(p, 'Master and/or victim not found'); // Add error if records not found
            }
            
            System.Savepoint sp = Database.setSavepoint(); // Set savepoint to rollback on error;
            
            try {
                
                commitMerge(dmlWrapper); // Commit merge to database
                
            } catch (Exception e) {
                
                // Rollback database and add error to all pairs
                Database.rollback(sp);
                addError(pairsToMerge, 'Error performing DML', e);
            }
            
            // Set status to merged for all successful merges
            for (Object_Merge_Pair__c p:pairsToMerge)
                if (p.Status__c == null)
                    p.Status__c = 'Merged';
        }
        
        // Method to query for and return map of parent records
        private Map<Id, SObject> getParentRecords(Set<Id> parentIds) {
			
            Map<Id, SObject> records = new Map<Id, SObject>(); // Instantiate map
            
            // Query records and put each in map individually (avoids query locator error)
            for (SObject so:queryRecords(parentIds))
                records.put(so.Id, so);
			
            return records; // Return map
        }
		
        // Method to query each child object and return map by child handler ID
        // Each map entry is another map with parent ID as key and list of child records as value
        private Map<Id, Map<Id, List<SObject>>> getChildRecords(Set<Id> parentIds) {
            
            Map<Id, Map<Id, List<SObject>>> childRecords = new Map<Id, Map<Id, List<SObject>>>(); // Instantiate map
            
            // Loop over child handler wrappers, query child object, and populate map
            for (ObjectMergeHandlerWrapper childHandler:this.childHandlers) {
                
                // Instantiate map of child records by parent ID for this child handler
                Map<Id, List<SObject>> childHandlerRecords = new Map<Id, List<SObject>>();
                
                // Assign empty list of child records for each parent ID
                for (Id parentId:parentIds)
                    childHandlerRecords.put(parentId, new List<SObject>());
                
                // Query child object and put each record in map based on parent ID
                for (SObject so:childHandler.queryRecords(parentIds))
                	childHandlerRecords.get((Id)so.get(childHandler.lookupField.token)).add(so);
                
                // Add map to map by handler ID
                childRecords.put(childHandler.handlerId, childHandlerRecords);
            }
            
            return childRecords; // Return map
        }
        
        // Method to query field history for each child object and return map by child handler ID
        // Each map entry is another map with child record ID as key and map of latest field history value by field name
        private Map<Id, Map<Id, Map<String, SObject>>> getChildFieldHistory(Map<Id, Map<Id, List<SObject>>> children) {
            
            Map<Id, Map<Id, Map<String, SObject>>> childFieldHistory = new Map<Id, Map<Id, Map<String, SObject>>>(); // Instantiate map
            
            // Loop over child handlers and query field history for each
            for (ObjectMergeHandlerWrapper childHandler:this.childHandlers) {
                
                childFieldHistory.put(childHandler.handlerId, new Map<Id, Map<String, SObject>>()); // Instantiate with empty map for each handler
                
                // Check to see if field history query is needed for this child handler
                if (childHandler.checkFieldHistory) {
                    
                    List<SObject> records = new List<SObject>(); // List of all child record for this handler
                    
                    // Loop over child records for each parent and get list of all child records for this child handler
                    for (List<SObject> childRecords:children.get(childHandler.handlerId).values())
                        records.addAll(childRecords);
                    
                    Set<Id> recordIds = (new Map<Id, SObject>(records)).keySet(); // Get set of IDs from list
                    
                    // Query field history and put in map
                    childFieldHistory.put(childHandler.handlerId, childHandler.queryFieldHistory(recordIds));
                }
            }
            
            return childFieldHistory; // Return field history
        }
        
        // Method to query object and return list of records
        private List<SObject> queryRecords(Set<Id> parentIds) {
			
            // Query object for this handler based on queryFields, name, and lookupField if this is a child object (Id otherwise)
            String query = 'SELECT ' + String.join(new List<String>(this.queryFields), ', ') + ' FROM ' + this.name + ' WHERE ' + (this.lookupField == null ? 'Id' : this.lookupField.Name) + ' IN :parentIds';
            
            return Database.query(query); // Query database and return result
        }
        
        // Method to query field history tracking object and return map of last changed values for each record ID/field
        private Map<Id, Map<String, SObject>> queryFieldHistory(Set<Id> recordIds) {
            
            Map<Id, Map<String, SObject>> fieldHistoryMap = new Map<Id, Map<String, SObject>>(); // Map of latest field history record for each field by parent ID
            
            // Check to see if field history needs to be checked for this object
            if (this.checkFieldHistory && !recordIds.isEmpty()) {
            	
                // Loop over all parents and instantiate new field history map for each parent ID
                for (Id recordId:recordIds)
                    fieldHistoryMap.put(recordId, new Map<String, SObject>());
                
                // Build field history object query
                String query = 'SELECT Field, CreatedDate, ' + this.historyObjectParentFieldName + ' FROM ' + this.historyObjectName + ' WHERE ' + this.historyObjectParentFieldName + ' IN :recordIds AND (Field IN :keepLeastRecentValueFields OR Field IN :keepMostRecentValueFields) ORDER BY CreatedDate DESC';
                
                for (SObject history:Database.query(query)) {
                    
                    String fieldName = ((String)history.get('Field')).toLowerCase(); // Get lowercased field name
                    Map<String, SObject> fieldHistory = fieldHistoryMap.get((Id)history.get(this.historyObjectParentFieldName)); // Get field history map for this parent record
                    
                    // Put history record in field history map for this parent record if map doesn't contain this field yet
                    if (!fieldHistory.containsKey(fieldName))
                        fieldHistory.put(fieldName, history);
                }
            }
            
            return fieldHistoryMap; // Return map
        }
        
        // Method to filter-out pairs with Victim ID of Contact that has active user
        private List<Object_Merge_Pair__c> getPairsToMerge(List<Object_Merge_Pair__c> pairs) {
            
            // Don't filter if this handler isn't a Contact handler that handles users
            if (!this.handleUser)
                return pairs;
            
            Set<Id> contactIds = new Set<Id>(); // Set of Victim Contact IDs
            
            // Loop over pairs and get set of victim Contact IDs
            for (Object_Merge_Pair__c p:pairs)
                contactIds.add(Id.valueOf(p.Victim_ID__c));
            
            Set<Id> contactIdsToSkip = new Set<Id>(); // Set of User IDs tied to victim Contacts
            
            // Query for users tied to victim contacts and get set of IDs for those users
            for (SObject u:Database.query('SELECT Id, ContactId FROM User WHERE IsPortalEnabled = true AND ContactId IN :contactIds'))
                contactIdsToSkip.add((Id)u.get('ContactId'));
            
            List<Object_Merge_Pair__c> pairsToMerge = new List<Object_Merge_Pair__c>(); // Instantiate list of pairs to merge
            
            // Loop over all pairs and filter-out those with Victim ID of Contact tied to active user
            for (Object_Merge_Pair__c p:pairs) {
                
                Id contactId = Id.valueOf(p.Victim_ID__c); // Grab Victim Contact ID
                
                // Set status to Processing for after trigger to deactivate user if ID in list to skip.
                // Otherwise, add pair to list to merge
                if (contactIdsToSkip.contains(contactId))
                    p.Status__c = 'Processing';
                else
                    pairsToMerge.add(p);
            }
            
            return pairsToMerge; // Return pairs to merge
        }
        
        // Method to merge two parent records and their children
        private void mergeRecords(SObject master, SObject victim, Map<String, SObject> masterFieldHistory, Map<String, SObject> victimFieldHistory, Map<Id, Map<Id, List<SObject>>> children, Map<Id, Map<Id, Map<String, SObject>>> childFieldHistory, ObjectMergeDMLWrapper dmlWrapper, Map<Id, Id> ownerIdMap) {
            
            // Merge parents and add to master update list if needed
            if (mergeFields(master, victim, masterFieldHistory, victimFieldHistory))
                dmlWrapper.addUpdate(master);
            
            dmlWrapper.addDelete(victim); // Add victim to delete list
            
            // Loop over each child handler wrapper and merge children
            for (ObjectMergeHandlerWrapper h:this.childHandlers)
                h.mergeChildRecords(master, victim, children.get(h.handlerId).get(master.Id), children.get(h.handlerId).get(victim.Id), childFieldHistory.get(h.handlerId), dmlWrapper.getChildWrapper(h.handlerId), ownerIdMap);
        }
        
        // Method to merge each victim field into master field if master field is not null
        // Returns true if at least one field is updated
        private Boolean mergeFields(SObject master, SObject victim, Map<String, SObject> masterFieldHistory, Map<String, SObject> victimFieldHistory) {
            
            Boolean ret = false; // Return false by default
            
            // Loop over all fields in this handler
            for (ObjectMergeFieldWrapper f:this.fields) {
                
                Object masterValue = master.get(f.token); // Get master field value
                Object victimValue = victim.get(f.token); // Get victim field value
                Boolean keepVictim = false; // Boolean that tracks if the victim value should be kept
                
                // Check to see if victim value was last updated if field is set to keep most recent value
                if (this.checkFieldHistory && (f.keepLeastRecentValue || f.keepMostRecentValue) && masterFieldHistory != null && victimFieldHistory != null) {
                    
                    // Get last update date/time from field history if it exists, otherwise created date of record
                    Datetime masterFieldUpdated = (Datetime)(masterFieldHistory.containsKey(f.name) ? masterFieldHistory.get(f.name) : master).get('CreatedDate');
                    Datetime victimFieldUpdated = (Datetime)(victimFieldHistory.containsKey(f.name) ? victimFieldHistory.get(f.name) : victim).get('CreatedDate');
                    
                    // Determine if victim value should be kept based on settings and last updated values
                    keepVictim = (f.keepLeastRecentValue && victimFieldUpdated < masterFieldUpdated) || (f.keepMostRecentValue && victimFieldUpdated > masterFieldUpdated);
                }
                
                // Check to see if master field value is null and victim field value is not null
                if (masterValue != victimValue && ((!f.keepNullValue && f.isNull(masterValue)) || (keepVictim && (f.keepNullValue || !f.isNull(victimValue))))) {
                    
                    master.put(f.token, victimValue); // Copy victim field value to master field
                    ret = true; // Return true because at least one field on master was updated
                }
            }
            
            return ret; // Return
        }
        
        // Method to merge child records between two parent records
        private void mergeChildRecords(SObject master, SObject victim, List<SObject> masterChildren, List<SObject> victimChildren, Map<Id, Map<String, SObject>> childFieldHistory, ObjectMergeDMLWrapper dmlWrapper, Map<Id, Id> ownerIdMap) {
            
            // Exit if no victim children to merge
            if (!victimChildren.isEmpty()) {
                
                // Get map of key for master children and corresponding children
                // Key is new SObject with only useForMatching fields populated
                Map<String, SObject> childMatchingMap = getChildMatchingMap(masterChildren);
                
                // Loop over victim children and handle based on handler settings
                for (SObject child:victimChildren) {
                    
                    // Key for victim child to match to master child with
                    // Key is new SObject with only useForMatching fields populated
                    String key = getChildCloneKey(child);
                    
                    // Check to see if matching record found and mergeAction populated
                    if (String.isNotBlank(this.mergeAction) && childMatchingMap.containsKey(key)) {
                        
                        SObject masterChild = childMatchingMap.get(key); // Grab master child record from map
                        Boolean keepMaster; // Boolean that determines whether we keep the master child or victim child
                        
                        // Populate keepMaster based on mergeAction
                        switch on this.mergeAction {
                            
                            when 'Delete Duplicate' {
                                
                                dmlWrapper.addDelete(child);
                                
                            } when 'Keep Oldest Created' {
                                
                                keepMaster = (Datetime)masterChild.get('CreatedDate') <= (Datetime)child.get('CreatedDate');
                                
                            } when 'Keep Newest Created' {
                                
                                keepMaster = (Datetime)masterChild.get('CreatedDate') >= (Datetime)child.get('CreatedDate');
                                
                            } when 'Keep Last Modified' {
                                
                                keepMaster = (Datetime)masterChild.get('LastModifiedDate') >= (Datetime)child.get('LastModifiedDate');
                                
                            } when else {
                                
                                keepMaster = true;
                            }
                        }
                        
                        // Merge child records if keepMaster set (mergeAction is not Delete Duplicate)
                        if (keepMaster != null)
                            mergeChildren(keepMaster, masterChild, child, childFieldHistory.get(masterChild.Id), childFieldHistory.get(child.Id), dmlWrapper, ownerIdMap);
                        
                    } else {
                        
                        // Handle non-merged victim record based on standardAction
                        switch on this.standardAction {
                            
                            when 'Move Victim' {
                                
                                handleChildLookups(child, master.Id, ownerIdMap); // Reparent victim
                        		dmlWrapper.addUpdate(child); // Add to update list
                                
                            } when 'Clone Victim' {
                                
                                SObject newChild = child.clone(false, true, false, false); // Clone victim
                                handleChildLookups(newChild, master.Id, ownerIdMap); // Associate with parent
                                dmlWrapper.addInsert(newChild); // Add newly cloned victim to insert list
                                dmlWrapper.addDelete(child); // Add original victim to delete list
                                
                            } when 'Delete Victim' {
                                
                                dmlWrapper.addDelete(child); // Add victim to delete list
                            }
                        }
                    }
                }
            }
        }
        
        // Method to return map of child records with key a new SObject
        // instance with only useForMatching fields populated
        private Map<String, SObject> getChildMatchingMap(List<SObject> children) {
            
            Map<String, SObject> childMatchingMap = new Map<String, SObject>(); // Instantiate map
            
            // Loop over child records and populate map with key if matching fields not empty
            if (!this.matchingFields.isEmpty())
                for (SObject child:children)
                    childMatchingMap.put(getChildCloneKey(child), child);
            
            return childMatchingMap; // Return map
        }
        
        // Method to generate new instance of object with only matching fields populated
        private String getChildCloneKey(SObject child) {
            
            String key; // Key to return
            
            // Skip if no matching fields
            if (!this.matchingFields.isEmpty()) {
                
                SObject childClone = this.token.newSObject(); // Instantiate new object
                
                // Loop over matching fields and copy values to new object instance
                for (ObjectMergeFieldWrapper f:this.matchingFields)
                    childClone.put(f.token, child.get(f.token));
                
                key = String.valueOf(childClone); // Set key to string value of new object instance
            }
            
            return key; // Return key
        }
		
        // Method to merge two child records and add to update/delete lists
        private void mergeChildren(Boolean masterWins, SObject master, SObject victim, Map<String, SObject> masterFieldHistory, Map<String, SObject> victimFieldHistory, ObjectMergeDMLWrapper dmlWrapper, Map<Id, Id> ownerIdMap) {
            
            // Merge victim into master if master record wins
            if (masterWins) {
                
                // Merge fields and add to update list if needed
                if (mergeFields(master, victim, masterFieldHistory, victimFieldHistory))
                    dmlWrapper.addUpdate(master);
                
                dmlWrapper.addDelete(victim); // Add to delete list
                
            } else {
                
                SObject child = this.cloneReparentedVictim ? victim.clone(false, true, false, false) : victim; // Clone victim if needed
                handleChildLookups(child, (Id)master.get(this.lookupField.token), ownerIdMap); // Populate lookups
                mergeFields(child, master, victimFieldHistory, masterFieldHistory); // Merge fields
                dmlWrapper.addDelete(master); // Add master record to delete list
                
                // Check to see if we need to clone reparented victim record
                if (this.cloneReparentedVictim) {
                    
                    dmlWrapper.addInsert(child); // Add cloned victim record to insert list
                    dmlWrapper.addDelete(victim); // Add victim record to delete list
                    
                } else {
                    dmlWrapper.addUpdate(victim); // Add re-parented victim record to update list
                }
            }
        }
        
        // Method to populate lookups (parent and owner) on child record
        private void handleChildLookups(SObject record, Id parentId, Map<Id, Id> ownerIdMap) {
            
            record.put(this.lookupField.token, parentId); // Populate parent lookup field with parentId
            
            // Update OwnerId with master Contact's User ID if current Owner ID is victim Contact's User ID
            if (this.hasOwner && ownerIdMap != null && ownerIdMap.containsKey((Id)record.get('OwnerId')))
                record.put('OwnerId', ownerIdMap.get((Id)record.get('OwnerId')));
        }
        
        // Method to commit merge to the database
        private void commitMerge(ObjectMergeDMLWrapper dmlWrapper) {
            
            dmlWrapper.commitMerge(this.childHandlers); // Call commit merge and pass-in child handlers
        }
    }
    
    // Wrapper class for Object Merge Fields
    private class ObjectMergeFieldWrapper {
        
        private Schema.SObjectField token; // Field type
        private Schema.DescribeFieldResult describe; // Field describe
        private String name; // Field API name (lowercase)
        private List<Schema.SObjectType> referenceObjects; // List of object types that this field references (if reference field)
        private Boolean useForMatching; // Boolean to track whether this field is used for matching
        private Boolean keepLeastRecentValue; // Boolean to track whether to look at Field History Tracking data to get the least recent value of this field
        private Boolean keepMostRecentValue; // Boolean to track whether to look at Field History Tracking data to get the most recent value of this field
        private Boolean keepNullValue; // Boolean to track whether a null value is considered
        private Boolean treatFalseAsNull; // Boolean to track whether a value of false should be treated as null for checkbox fields
		
        // Constructor for lookup fields and merge all fields fields
        private ObjectMergeFieldWrapper(Schema.SObjectField token) {
			
            this(token, false, false, false, false, false); // Call constructor with all booleans false
        }
		
        // Constructor (primary)
        private ObjectMergeFieldWrapper(Schema.SObjectField token, Boolean useForMatching, Boolean keepLeastRecentValue, Boolean keepMostRecentValue, Boolean keepNullValue, Boolean treatFalseAsNull) {
            
            this.token = token; // Set field type
            this.describe = token.getDescribe(); // Set describe
            this.name = this.describe.getName().toLowerCase(); // Set API name from describe and lowercase it
            this.referenceObjects = this.describe.getReferenceTo(); // Set referenceObjects from describe (returns null if non-reference field)
            this.useForMatching = useForMatching; // Set useForMatching
            this.keepLeastRecentValue = keepLeastRecentValue; // Set keepLeastRecentValue
            this.keepMostRecentValue = keepMostRecentValue; // Set keepMostRecentValue
            this.keepNullValue = keepNullValue; // Set keepNullValue
            this.treatFalseAsNull = treatFalseAsNull; // Set treatFalseAsNull
        }
        
        // Method to return true if a value for this field is null
        private Boolean isNull(Object value) {
            
            return value == null || (this.treatFalseAsNull && value == false); // Return true if value is null or false with treatFalseAsNull set
        }
    }
    
    // Wrapper class to track all records to perform DML on
    private class ObjectMergeDMLWrapper {
        
        private List<SObject> recordsToInsert; // List of records to insert
        private List<SObject> recordsToUpdate; // List of records to update
        private List<SObject> recordsToDelete; // List of records to delete
        private Map<Id, ObjectMergeDMLWrapper> childWrappers; // Map of DML wrappers for each child handler ID
        
        // Constructor for child handler DML wrappers
        private ObjectMergeDMLWrapper() {
            
            // Instantiate lists
            this.recordsToInsert = new List<SObject>();
            this.recordsToUpdate = new List<SObject>();
            this.recordsToDelete = new List<SObject>();
        }
        
        private ObjectMergeDMLWrapper(List<ObjectMergeHandlerWrapper> childHandlers) {
            
            this(); // Call child handler constructor to instantiate lists
            this.childWrappers = new Map<Id, ObjectMergeDMLWrapper>(); // Instantiate map of child handler DML wrappers
            
            // Loop over child handlers and create DML wrapper for each
            for (ObjectMergeHandlerWrapper h:childHandlers)
                this.childWrappers.put(h.handlerId, new ObjectMergeDMLWrapper());
        }
        
        // Method to add record to insert list
        private void addInsert(SObject toInsert) {
            
            this.recordsToInsert.add(toInsert); // Add record to list
        }
        
        // Method to add record to update list
        private void addUpdate(SObject toUpdate) {
            
            this.recordsToUpdate.add(toUpdate); // Add record to list
        }
        
        // Method to add record to delete list
        private void addDelete(SObject toDelete) {
            
            this.recordsToDelete.add(toDelete); // Add record to list
        }
        
        // Method to get child handler DML wrapper based on handlerId
        private ObjectMergeDMLWrapper getChildWrapper(Id handlerId) {
            
            return this.childWrappers.get(handlerId); // Return DML wrapper from map
        }
        
        // Method to commit merge to the database
        private void commitMerge(List<ObjectMergeHandlerWrapper> childHandlers) {
            
            // Get set of all record IDs to delete among parent and child handlers
            Set<Id> recordsToDeleteIds = getRecordsToDeleteIds();
            for (ObjectMergeDMLWrapper childWrapper:this.childWrappers.values())
                recordsToDeleteIds.addAll(childWrapper.getRecordsToDeleteIds());
            
            // Loop over each child handler in order and perform DML for it
            for (ObjectMergeHandlerWrapper h:childHandlers)
                this.childWrappers.get(h.handlerId).performDML(recordsToDeleteIds);
            
            performDML(recordsToDeleteIds); // Perform DML for parent handler
        }
        
        // Method that returns set of IDs in recordsToDelete list
        private Set<Id> getRecordsToDeleteIds() {
            
            return (new Map<Id, SObject>(this.recordsToDelete)).keySet().clone(); // Clone map key set and return
        }
        
        // Method to perform the DML for this DML wrapper
        private void performDML(Set<Id> recordsToDeleteIds) {
            
            List<SObject> recordsToDeleteList = new List<SObject>(); // De-duped list of records to delete
            Set<Id> recordsToDeleteIdsSet = new Set<Id>(); // Set of IDs that have been added to de-duped list already
            
            // Loop over recordsToDelete and add to de-duped list if not already there
            for (SObject so:this.recordsToDelete) {
                
                if (!recordsToDeleteIdsSet.contains(so.Id)) {
                    
                    recordsToDeleteIdsSet.add(so.Id);
                    recordsToDeleteList.add(so);
                }
            }
            
            List<SObject> recordsToUpdateList = new List<SObject>(); // De-duped list of records to update
            Set<Id> recordsToUpdateIds = new Set<Id>(); // Set of IDs that have been added to de-duped list already
            
            // Loop over recordsToUpdate and add to de-duped list if not already there and not in delete list
            for (SObject so:this.recordsToUpdate) {
                
                if (!recordsToUpdateIds.contains(so.Id) && !recordsToDeleteIds.contains(so.Id)) {
                    
                    recordsToUpdateIds.add(so.Id);
                    recordsToUpdateList.add(so);
                }
            }
            
            // Set DMLOptions to allow duplicates to get saved. This helps avoid
            // errors when updating master records before deleting victim records.
            Database.DMLOptions options = new Database.DMLOptions();
            options.optAllOrNone = true;
            options.DuplicateRuleHeader.AllowSave = true;
            
            // Update records
            Database.update(recordsToUpdateList, options);
            
            // Insert records
            Database.insert(this.recordsToInsert, options);
            
            List<Id> databaseErrorIds = new List<Id>(); // List of IDs that caused database errors
            List<Database.Error> databaseErrors = new List<Database.Error>(); // List of database errors
            
            // Delete records and handle ENTITY_IS_DELETED error if records got deleted due to other DML, otherwise add error to list of errors
            for (Database.DeleteResult dr:Database.delete(recordsToDeleteList, false)) {
                
                for (Database.Error er:dr.getErrors()) {
                    
                    if (er.getStatusCode() != StatusCode.ENTITY_IS_DELETED) {
                		
                        databaseErrorIds.add(dr.getId());
                        databaseErrors.add(er);
                    }
                }
            }
            
            // Throw exception if there is at least one error
            if (!databaseErrors.isEmpty())
                throw new ObjectMergeException(databaseErrorIds, databaseErrors);
        }
    }
    
    // Custom Exception class
    private class ObjectMergeException extends Exception {
        
        private List<Id> databaseErrorIds; // List of IDs of records that caused database errors
        private List<Database.Error> databaseErrors; // List of database errors
        
        // Contructor that allows you to pass-in database errors
        private ObjectMergeException(List<Id> databaseErrorIds, List<Database.Error> databaseErrors) {
            
            this.databaseErrorIds = databaseErrorIds; // Set databaseErrorIds
            this.databaseErrors = databaseErrors; // Set databaseErrors
        }
    }
}