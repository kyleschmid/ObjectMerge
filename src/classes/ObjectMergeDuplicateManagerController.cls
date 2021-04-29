/*
    BSD 3-Clause License
    
    Copyright (c) 2021, Kyle Schmid, Huron Consulting Group
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
public with sharing class ObjectMergeDuplicateManagerController {
	
    // Method to get duplicate record items from duplicate record sets that contain recordId
    @AuraEnabled
    public static DuplicateTableWrapper getDuplicates(Id recordId, String fieldString) {
        
        DuplicateTableWrapper wrapper = new DuplicateTableWrapper(); // Instantiate wrapper
        
        // Only query Duplicate Record Sets if recordId is non-null
        if (recordId != null) {
            
            // Get all Duplicate Record Set IDs that contain this recordId
            Set<Id> duplicateSetIds = new Set<Id>();
        	for (DuplicateRecordItem duplicateItem:[SELECT Id, DuplicateRecordSetId FROM DuplicateRecordItem WHERE RecordId = :recordId])
            	duplicateSetIds.add(duplicateItem.DuplicateRecordSetId);
            
            // Only continue if there is at least one Duplicate Record Set
            if (!duplicateSetIds.isEmpty() || Test.isRunningTest()) {
                
                // Get all Record IDs from Duplicate Record Sets
                Set<Id> recordIds = new Set<Id>();
                for (DuplicateRecordItem duplicateItem:[SELECT Id, RecordId FROM DuplicateRecordItem WHERE DuplicateRecordSetId IN :duplicateSetIds])
                    recordIds.add(duplicateItem.RecordId);
                
                // Only continue if there is at least one duplicate (more than one Record ID)
                if (recordIds.size() > 1 || Test.isRunningTest()) {
                    
                    Schema.DescribeSObjectResult objectDescribe = recordId.getSObjectType().getDescribe(); // Get describe information for this object
                    Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap(); // Get fields for this object
                    
                    Set<String> fieldNames = new Set<String>{'id', 'name'}; // Instantiate list of fields to query with Id
                    
                    // Add the Name field if it exists for this object
                    if (fieldMap.containsKey('Name'))
                        fieldNames.add('name');
                    
                    // Loop over field names specified in component and add to set
                    if (String.isNotBlank(fieldString)) {
                        
                        for (String fieldName:fieldString.deleteWhitespace().split(',')) {
                            
                            // Check to see if field is valid
                            if (fieldMap.containsKey(fieldName)) {
                                
                                fieldNames.add(fieldName.toLowerCase()); // Add field name to set
                                wrapper.addField(fieldMap.get(fieldName)); // Add field wrapper to list of field wrappers
                            }
                        }
                    }
                    
                    // Build query
                    String query = 'SELECT ' + String.join(new List<String>(fieldNames), ', ') + ' FROM ' + objectDescribe.getName() + ' WHERE Id IN :recordIds';
                    
                    // Query records and add to wrapper
                    wrapper.addRecords(Database.query(query), recordId);
                }
            }
        }
        
        return wrapper; // Return wrapper
    }
	
    // Method to merge two records
    @AuraEnabled
    public static Object_Merge_Pair__c mergeRecords(Id masterId, Id victimId) {
		
        // Instantiate Object Merge Pair
        Object_Merge_Pair__c mergePair = new Object_Merge_Pair__c(Master_Id__c = masterId, Victim_Id__c = victimId);
        
        // Query for existing Object Merge Pair
        List<Object_Merge_Pair__c> existingMergePair = [SELECT Id FROM Object_Merge_Pair__c WHERE Master_Id__c = :masterId AND Victim_Id__c = :victimId AND Status__c = 'Error' LIMIT 1];
        
        // Specify ID and set Status to Retry if Object Merge Pair already exists
        if (!existingMergePair.isEmpty()) {
            mergePair.Id = existingMergePair[0].Id;
            mergePair.Status__c = 'Retry';
        }
        
        upsert mergePair; // Upsert Object Merge Pair
        
        // Query and return upserted Object Merge Pair
        return [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :mergePair.Id];
    }
    
    // Method to get Object Merge Pair if records are being merged asynchronously because of community users
    @AuraEnabled
    public static Object_Merge_Pair__c getObjectMergePair(Id pairId) {
        
        // Query for object Merge Pair
        List<Object_Merge_Pair__c> pairs = [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :pairId];
        
        return pairs.isEmpty() ? null : pairs[0]; // Return null if Object Merge Pair not found, otherwise return Object Merge Pair
    }
    
    // Wrapper class for the Duplicate Record table on a Lightning Record Page
    public class DuplicateTableWrapper {
        
        @AuraEnabled public List<FieldWrapper> fields; // List of field wrappers to include
        @AuraEnabled public List<SObject> records; // List of records
        
        // Constructor
        public DuplicateTableWrapper() {
            
            // Instantiate lists
            this.fields = new List<FieldWrapper>();
            this.records = new List<SObject>();
        }
        
        // Method to create a new field wrapper and add to list
        public void addField(Schema.SObjectField fieldToken) {
            
            this.fields.add(new FieldWrapper(fieldToken)); // Create new field wrapper and add to list
        }
        
        // Method to add records to list
        public void addRecords(List<SObject> records, Id recordId) {
            
            Map<Id, SObject> recordMap = new Map<Id, SObject>(records); // Get map from list
            
            this.records.add(recordMap.get(recordId)); // Add record from record page as first in list
            recordMap.remove(recordId); // Remove record from record page from map
            this.records.addAll(recordMap.values()); // Add all values from map to list
        }
    }
	
    // Wrapper class for fields included in the Duplicate Record table
	public class FieldWrapper {
		
		@AuraEnabled public String fieldName; // API name of field
		@AuraEnabled public String label; // Label of field
		@AuraEnabled public String fieldType; // Type of field
		
        // Constructor
		public FieldWrapper(Schema.SObjectField fieldToken) {
			
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe(); // Get describe information from token
            
            // Instantiate attributes based on describe information
 			this.fieldName = fieldDescribe.getName();
			this.label = fieldDescribe.getLabel();
			this.fieldType = fieldDescribe.getType().name();
		}
    }
}