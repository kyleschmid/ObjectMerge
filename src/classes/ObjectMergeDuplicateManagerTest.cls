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
@isTest
private class ObjectMergeDuplicateManagerTest {
	
    @isTest
    static void test_get_duplicates() {
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        
        String fieldString = 'Phone, BillingStreet, not_a_field';
        
        Test.startTest();
        
        ObjectMergeDuplicateManagerController.DuplicateTableWrapper wrapper = ObjectMergeDuplicateManagerController.getDuplicates(a1Id, fieldString);
        
        Test.stopTest();
        
        System.assertEquals(2, wrapper.fields.size());
        System.assertEquals('Phone', wrapper.fields[0].fieldName);
        System.assertEquals('BillingStreet', wrapper.fields[1].fieldName);
        
        if (![SELECT Id FROM DuplicateRecordItem WHERE RecordId = :a1Id].isEmpty()) {
            
            System.assertEquals(2, wrapper.records.size());
            System.assertEquals(a1Id, wrapper.records[0].Id);
            System.assertEquals(a2Id, wrapper.records[1].Id);
        }
    }
    
    @isTest
    static void test_merge_records() {
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        
        Object_Merge_Pair__c p1 = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id, Status__c = 'Error');
        insert p1;
        
        Test.startTest();
        
        Object_Merge_Pair__c p2 = ObjectMergeDuplicateManagerController.mergeRecords(a1Id, a2Id);
        Object_Merge_Pair__c p3 = ObjectMergeDuplicateManagerController.getObjectMergePair(p1.Id);
        
        Test.stopTest();
        
        System.assertEquals(1, [SELECT Id FROM Account WHERE Id = :a1Id].size());
        System.assertEquals(0, [SELECT Id FROM Account WHERE Id = :a2Id].size());
        
        System.assertEquals(p1.Id, p2.Id);
        System.assertEquals(p1.Id, p3.Id);
        System.assertEquals('Merged', p2.Status__c);
    }
    
    @testSetup
    static void setup() {
        
        Id parentRtId = Schema.SObjectType.Object_Merge_Handler__c.getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        
        insert (new Object_Merge_Handler__c(Name = 'Account', Active__c = true, RecordTypeId = parentRtId));
        
        Account a1 = new Account(Name = 'test1');
        Account a2 = new Account(Name = 'test2');
        
        insert new List<Account>{a1, a2};
        
        List<DuplicateRule> rules = [SELECT Id FROM DuplicateRule WHERE SObjectType = 'Account' LIMIT 1];
        
        if (!rules.isEmpty()) {
            
            DuplicateRecordSet drs = new DuplicateRecordSet(DuplicateRuleId = rules[0].Id);
            insert drs;
            
            DuplicateRecordItem item1 = new DuplicateRecordItem(DuplicateRecordSetId = drs.Id, RecordId = a1.Id);
            DuplicateRecordItem item2 = new DuplicateRecordItem(DuplicateRecordSetId = drs.Id, RecordId = a2.Id);
            
            insert new List<DuplicateRecordItem>{item1, item2};
        }
    }
}