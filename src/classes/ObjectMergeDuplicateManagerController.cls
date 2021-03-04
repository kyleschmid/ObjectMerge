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
	
    @AuraEnabled
    public static DuplicateTableWrapper getDuplicates(Id recordId, String fieldString) {
        
        DuplicateTableWrapper wrapper = new DuplicateTableWrapper();
        
        if (recordId != null) {
            
            // Get all Duplicate Record Set IDs that contain this recordId
            Set<Id> duplicateSetIds = new Set<Id>();
        	for (DuplicateRecordItem duplicateItem:[SELECT Id, DuplicateRecordSetId FROM DuplicateRecordItem WHERE RecordId = :recordId])
            	duplicateSetIds.add(duplicateItem.DuplicateRecordSetId);
            
            if (!duplicateSetIds.isEmpty() || Test.isRunningTest()) {
                
                // Get all Record IDs from Duplicate Record Sets
                Set<Id> recordIds = new Set<Id>();
                for (DuplicateRecordItem duplicateItem:[SELECT Id, RecordId FROM DuplicateRecordItem WHERE DuplicateRecordSetId IN :duplicateSetIds])
                    recordIds.add(duplicateItem.RecordId);
                
                if (recordIds.size() > 1 || Test.isRunningTest()) {
                    
                    Schema.DescribeSObjectResult objectDescribe = recordId.getSObjectType().getDescribe();
                    Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
                    
                    Set<String> fieldNames = new Set<String>{'id', 'name'};
                    
                    if (String.isNotBlank(fieldString)) {
                        
                        for (String fieldName:fieldString.deleteWhitespace().split(',')) {
                            
                            if (fieldMap.containsKey(fieldName)) {
                                
                                fieldNames.add(fieldName.toLowerCase());
                                wrapper.addField(fieldMap.get(fieldName));
                            }
                        }
                    }
                    
                    String query = 'SELECT ' + String.join(new List<String>(fieldNames), ', ') + ' FROM ' + objectDescribe.getName() + ' WHERE Id IN :recordIds';
                    
                    wrapper.addRecords(Database.query(query), recordId);
                }
            }
        }
        
        return wrapper;
    }
	
    @AuraEnabled
    public static Object_Merge_Pair__c mergeRecords(Id masterId, Id victimId) {
		
        Object_Merge_Pair__c mergePair = new Object_Merge_Pair__c(Master_Id__c = masterId, Victim_Id__c = victimId);
        
        List<Object_Merge_Pair__c> existingMergePair = [SELECT Id FROM Object_Merge_Pair__c WHERE Master_Id__c = :masterId AND Victim_Id__c = :victimId AND Status__c = 'Error' LIMIT 1];
        if (!existingMergePair.isEmpty()) {
            mergePair.Id = existingMergePair[0].Id;
            mergePair.Status__c = 'Retry';
        }
        
        upsert mergePair;
        
        return [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :mergePair.Id];
    }
    
    @AuraEnabled
    public static Object_Merge_Pair__c getObjectMergePair(Id pairId) {
        
        List<Object_Merge_Pair__c> pairs = [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :pairId];
        
        return pairs.isEmpty() ? null : pairs[0];
    }
    
    public class DuplicateTableWrapper {
        
        @AuraEnabled public List<FieldWrapper> fields;
        @AuraEnabled public List<SObject> records;
        
        public DuplicateTableWrapper() {
            
            this.fields = new List<FieldWrapper>();
            this.records = new List<SObject>();
        }
        
        public void addField(Schema.SObjectField fieldToken) {
            
            this.fields.add(new FieldWrapper(fieldToken));
        }
        
        public void addRecords(List<SObject> records, Id recordId) {
            
            Map<Id, SObject> recordMap = new Map<Id, SObject>(records);
            
            this.records.add(recordMap.get(recordId));
            recordMap.remove(recordId);
            this.records.addAll(recordMap.values());
        }
    }
	
	public class FieldWrapper {
		
		@AuraEnabled public String fieldName;
		@AuraEnabled public String label;
		@AuraEnabled public String fieldType;
		
		public FieldWrapper(Schema.SObjectField fieldToken) {
			
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            
 			this.fieldName = fieldDescribe.getName();
			this.label = fieldDescribe.getLabel();
			this.fieldType = fieldDescribe.getType().name();
		}
    }
}