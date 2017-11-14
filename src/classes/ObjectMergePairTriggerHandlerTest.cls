/*
BSD 3-Clause License

Copyright (c) 2017, Huron Consulting Group
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
private class ObjectMergePairTriggerHandlerTest {
	
    @isTest
    static void test_move_victim_keep_master() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = :'Contact'];
        h2.Standard_Action__c = 'Move Victim';
        h2.Merge_Action__c = 'Keep Master';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = :'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = :'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = :'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = :'test2'].Id;
        Id c3Id = [SELECT Id FROM Contact WHERE LastName = :'test3'].Id;
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        Contact c1 = [SELECT Id, AccountId, LastName, Email FROM Contact WHERE Id = :c1Id];
        System.assertEquals(a1Id, c1.AccountId);
        System.assertEquals('test1', c1.LastName);
        System.assertEquals('test@test.com', c1.Email);
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
        
        Contact c3 = [SELECT Id, AccountId FROM Contact WHERE Id = :c3Id];
        System.assertEquals(a1Id, c3.AccountId);
    }
    
    @isTest
    static void test_delete_victim_delete_duplicate() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = :'Contact'];
        h2.Standard_Action__c = 'Delete Victim';
        h2.Merge_Action__c = 'Delete Duplicate';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = :'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = :'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = :'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = :'test2'].Id;
        Id c3Id = [SELECT Id FROM Contact WHERE LastName = :'test3'].Id;
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        Contact c1 = [SELECT Id, AccountId, LastName, Email FROM Contact WHERE Id = :c1Id];
        System.assertEquals(a1Id, c1.AccountId);
        System.assertEquals('test1', c1.LastName);
        System.assertEquals(null, c1.Email);
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c3Id].isEmpty());
    }
    
    @isTest
    static void test_clone_victim_clone_reparented_victim() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = :'Contact'];
        h2.Standard_Action__c = 'Clone Victim';
        h2.Merge_Action__c = 'Keep Oldest Created';
        h2.Clone_Reparented_Victim__c = true;
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = :'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = :'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = :'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = :'test2'].Id;
        Id c3Id = [SELECT Id FROM Contact WHERE LastName = :'test3'].Id;
        
        Test.setCreatedDate(c1Id, System.NOW().addMinutes(1));
        Test.setCreatedDate(c2Id, System.NOW().addMinutes(-1));
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c1Id].isEmpty());
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
        System.assert([SELECT Id FROM Contact WHERE Id = :c3Id].isEmpty());
        
        Contact clone = [SELECT Id, AccountId, LastName, Email FROM Contact WHERE LastName = :'test2'];
        System.assertEquals(a1Id, clone.AccountId);
        System.assertEquals('test@test.com', clone.Email);
        
        Contact c3New = [SELECT Id, AccountId FROM Contact WHERE LastName = :'test3'];
        System.assertEquals(a1Id, c3New.AccountId);
    }
    
    @isTest
    static void test_keep_oldest_created() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = :'Contact'];
        h2.Merge_Action__c = 'Keep Oldest Created';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = :'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = :'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = :'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = :'test2'].Id;
        
        Test.setCreatedDate(c1Id, System.NOW().addMinutes(1));
        Test.setCreatedDate(c2Id, System.NOW().addMinutes(-1));
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c1Id].isEmpty());
        
        Contact c2 = [SELECT Id, AccountId, LastName, Email FROM Contact WHERE Id = :c2Id];
        System.assertEquals(a1Id, c2.AccountId);
        System.assertEquals('test2', c2.LastName);
        System.assertEquals('test@test.com', c2.Email);
    }
    
    @isTest
    static void test_keep_newest_created() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = :'Contact'];
        h2.Merge_Action__c = 'Keep Newest Created';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = :'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = :'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = :'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = :'test2'].Id;
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        Contact c1 = [SELECT Id, AccountId, LastName, Email FROM Contact WHERE Id = :c1Id];
        System.assertEquals(a1Id, c1.AccountId);
        System.assertEquals('test1', c1.LastName);
        System.assertEquals('test@test.com', c1.Email);
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
    }
    
    @isTest
    static void test_keep_last_modified() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = :'Contact'];
        h2.Merge_Action__c = 'Keep Last Modified';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = :'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = :'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = :'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = :'test2'].Id;
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        Contact c1 = [SELECT Id, AccountId, LastName, Email FROM Contact WHERE Id = :c1Id];
        System.assertEquals(a1Id, c1.AccountId);
        System.assertEquals('test1', c1.LastName);
        System.assertEquals('test@test.com', c1.Email);
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
    }
    
    @isTest
    static void test_errors_1() {
        
        Object_Merge_Field__c f = [SELECT Id FROM Object_Merge_Field__c WHERE Object_Merge_Handler__r.Name = :'Contact' LIMIT 1];
        f.Name = 'not_a_field';
        update f;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = :'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = :'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = :'test1'].Id;
        
        Object_Merge_Pair__c p1 = new Object_Merge_Pair__c(Status__c = 'Retry', Master_ID__c = a1Id, Victim_ID__c = a2Id);
        Object_Merge_Pair__c p2 = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = c1Id);
        Object_Merge_Pair__c p3 = new Object_Merge_Pair__c(Master_ID__c = '00T0H00003uKOXt', Victim_ID__c = '00T0H00003uKOXt');
        Object_Merge_Pair__c p4 = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert new List<Object_Merge_Pair__c>{p1, p2, p3, p4};
        
        Test.stopTest();
        
        p1 = [SELECT Id, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p1.Id];
        p2 = [SELECT Id, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p2.Id];
        p3 = [SELECT Id, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p3.Id];
        p4 = [SELECT Id, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p4.Id];
        
        System.assertEquals('Invalid status', p1.Error_Reason__c);
        System.assertEquals('Invalid Master/Victim ID pair', p2.Error_Reason__c);
        System.assertEquals('Object Merge Handler not found', p3.Error_Reason__c);
        System.assertEquals('Error running query', p4.Error_Reason__c);
    }
    
    @isTest
    static void test_errors_2() {
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = :'test1'].Id;
        
        Account a2 = [SELECT Id FROM Account WHERE Name = :'test2'];
        delete a2;
        
        Id a2Id = a2.Id;
        
        Object_Merge_Pair__c p1 = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p1;
        
        Test.stopTest();
        
        p1 = [SELECT Id, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p1.Id];
        
        System.assertEquals('Master and/or victim not found', p1.Error_Reason__c);
    }
    
    @isTest
    static void test_errors_3() {
        
        Object_Merge_Field__c f = [SELECT Id FROM Object_Merge_Field__c WHERE Object_Merge_Handler__r.Name = :'Account' LIMIT 1];
        f.Name = 'ParentId';
        update f;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = :'test1'].Id;
        
        Account a2 = [SELECT Id FROM Account WHERE Name = :'test2'];
        a2.ParentId = a1Id;
        update a2;
        
        Id a2Id = a2.Id;
        
        Object_Merge_Pair__c p1 = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p1;
        
        Test.stopTest();
        
        p1 = [SELECT Id, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p1.Id];
        
        System.assertEquals('Error performing DML', p1.Error_Reason__c);
    }
    
    @testSetup
    static void setup() {
        
        Account a1 = new Account(Name = 'test1');
        Account a2 = new Account(Name = 'test2', Website = 'www.test2.com');
        insert new List<Account>{a1, a2};
        
        Contact c1 = new Contact(AccountId = a1.Id, LastName = 'test1', FirstName = 'test');
        Contact c2 = new Contact(AccountId = a2.Id, LastName = 'test2', FirstName = 'test', Email = 'test@test.com');
        Contact c3 = new Contact(AccountId = a2.Id, LastName = 'test3', FirstName = 'not_test');
        insert new List<Contact>{c1, c2, c3};
        
        Id pId = Schema.SObjectType.Object_Merge_Handler__c.getRecordTypeInfosByName().get('Parent Handler').getRecordTypeId();
        Id cId = Schema.SObjectType.Object_Merge_Handler__c.getRecordTypeInfosByName().get('Child Handler').getRecordTypeId();
        
        Object_Merge_Handler__c h1 = new Object_Merge_Handler__c(Name = 'Account', Active__c = true, RecordTypeId = pId);
        insert h1;
        Object_Merge_Handler__c h2 = new Object_Merge_Handler__c(Name = 'Contact', Active__c = true, Standard_Action__c = 'Delete Victim', RecordTypeId = cId, Child_Relationship_Name__c = 'Contacts', Object_Lookup_Field_API_Name__c = 'AccountId', Parent_Handler__c = h1.Id);
        insert h2;
        
        Object_Merge_Field__c f1 = new Object_Merge_Field__c(Name = 'Name', Use_for_Matching__c = false, Object_Merge_Handler__c = h1.Id, Active__c = true);
        Object_Merge_Field__c f2 = new Object_Merge_Field__c(Name = 'Website', Use_for_Matching__c = false, Object_Merge_Handler__c = h1.Id, Active__c = true);
        Object_Merge_Field__c f3 = new Object_Merge_Field__c(Name = 'LastName', Use_for_Matching__c = false, Object_Merge_Handler__c = h2.Id, Active__c = true);
        Object_Merge_Field__c f4 = new Object_Merge_Field__c(Name = 'FirstName', Use_for_Matching__c = true, Object_Merge_Handler__c = h2.Id, Active__c = true);
        Object_Merge_Field__c f5 = new Object_Merge_Field__c(Name = 'Email', Use_for_Matching__c = false, Object_Merge_Handler__c = h2.Id, Active__c = true);
        insert new List<Object_Merge_Field__c>{f1, f2, f3, f4, f5};
    }
}