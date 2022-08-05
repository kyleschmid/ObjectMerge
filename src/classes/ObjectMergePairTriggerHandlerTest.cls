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
private class ObjectMergePairTriggerHandlerTest {
    
    @isTest
    static void test_move_victim_keep_master() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Contact' AND RecordType.DeveloperName = 'Child_Handler'];
        h2.Standard_Action__c = 'Move Victim';
        h2.Merge_Action__c = 'Keep Master';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = 'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = 'test2'].Id;
        Id c3Id = [SELECT Id FROM Contact WHERE LastName = 'test3'].Id;
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        update p;
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals('Merged', p.Status__c);
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        Contact c1 = [SELECT Id, AccountId, LastName, Email, DoNotCall, HasOptedOutOfEmail FROM Contact WHERE Id = :c1Id];
        System.assertEquals(a1Id, c1.AccountId);
        System.assertEquals('test1', c1.LastName);
        System.assertEquals('test@test.com', c1.Email);
        System.assertEquals(false, c1.DoNotCall);
        System.assertEquals(true, c1.HasOptedOutOfEmail);
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
        
        Contact c3 = [SELECT Id, AccountId FROM Contact WHERE Id = :c3Id];
        System.assertEquals(a1Id, c3.AccountId);
    }
    
    @isTest
    static void test_delete_victim_delete_duplicate() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Contact' AND RecordType.DeveloperName = 'Child_Handler'];
        h2.Standard_Action__c = 'Delete Victim';
        h2.Merge_Action__c = 'Delete Duplicate';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = 'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = 'test2'].Id;
        Id c3Id = [SELECT Id FROM Contact WHERE LastName = 'test3'].Id;
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals('Merged', p.Status__c);
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        Contact c1 = [SELECT Id, AccountId, LastName, Email, DoNotCall, HasOptedOutOfEmail FROM Contact WHERE Id = :c1Id];
        System.assertEquals(a1Id, c1.AccountId);
        System.assertEquals('test1', c1.LastName);
        System.assertEquals(null, c1.Email);
        System.assertEquals(false, c1.DoNotCall);
        System.assertEquals(false, c1.HasOptedOutOfEmail);
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c3Id].isEmpty());
    }
    
    @isTest
    static void test_clone_victim_clone_reparented_victim() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Contact' AND RecordType.DeveloperName = 'Child_Handler'];
        h2.Standard_Action__c = 'Clone Victim';
        h2.Merge_Action__c = 'Keep Oldest Created';
        h2.Clone_Reparented_Victim__c = true;
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = 'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = 'test2'].Id;
        Id c3Id = [SELECT Id FROM Contact WHERE LastName = 'test3'].Id;
        
        Test.setCreatedDate(c1Id, System.now().addHours(-1));
        Test.setCreatedDate(c2Id, System.now().addHours(-2));
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals('Merged', p.Status__c);
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c1Id].isEmpty());
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
        System.assert([SELECT Id FROM Contact WHERE Id = :c3Id].isEmpty());
        
        Contact clone = [SELECT Id, AccountId, LastName, Email, DoNotCall, HasOptedOutOfEmail FROM Contact WHERE LastName = 'test2'];
        System.assertEquals(a1Id, clone.AccountId);
        System.assertEquals('test@test.com', clone.Email);
        System.assertEquals(true, clone.DoNotCall);
        System.assertEquals(true, clone.HasOptedOutOfEmail);
        
        Contact c3New = [SELECT Id, AccountId FROM Contact WHERE LastName = 'test3'];
        System.assertEquals(a1Id, c3New.AccountId);
    }
    
    @isTest
    static void test_keep_oldest_created() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Contact' AND RecordType.DeveloperName = 'Child_Handler'];
        h2.Merge_Action__c = 'Keep Oldest Created';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = 'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = 'test2'].Id;
        
        Test.setCreatedDate(c1Id, System.now().addHours(-1));
        Test.setCreatedDate(c2Id, System.now().addHours(-2));
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals('Merged', p.Status__c);
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c1Id].isEmpty());
        
        Contact c2 = [SELECT Id, AccountId, LastName, Email, DoNotCall, HasOptedOutOfEmail FROM Contact WHERE Id = :c2Id];
        System.assertEquals(a1Id, c2.AccountId);
        System.assertEquals('test2', c2.LastName);
        System.assertEquals('test@test.com', c2.Email);
        System.assertEquals(true, c2.DoNotCall);
        System.assertEquals(true, c2.HasOptedOutOfEmail);
    }
    
    @isTest
    static void test_keep_newest_created() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Contact' AND RecordType.DeveloperName = 'Child_Handler'];
        h2.Merge_Action__c = 'Keep Newest Created';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = 'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = 'test2'].Id;
        
        Test.setCreatedDate(c1Id, System.now().addHours(-1));
        Test.setCreatedDate(c2Id, System.now().addHours(-2));
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals('Merged', p.Status__c);
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        Contact c1 = [SELECT Id, AccountId, LastName, Email, DoNotCall, HasOptedOutOfEmail FROM Contact WHERE Id = :c1Id];
        System.assertEquals(a1Id, c1.AccountId);
        System.assertEquals('test1', c1.LastName);
        System.assertEquals('test@test.com', c1.Email);
        System.assertEquals(false, c1.DoNotCall);
        System.assertEquals(true, c1.HasOptedOutOfEmail);
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
    }
    
    @isTest
    static void test_keep_last_modified() {
        
        Object_Merge_Handler__c h2 = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Contact' AND RecordType.DeveloperName = 'Child_Handler'];
        h2.Merge_Action__c = 'Keep Last Modified';
        update h2;
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = 'test1'].Id;
        Id c2Id = [SELECT Id FROM Contact WHERE LastName = 'test2'].Id;
        
        update (new Contact(Id = c1Id));
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals('Merged', p.Status__c);
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        Contact c1 = [SELECT Id, AccountId, LastName, Email, DoNotCall, HasOptedOutOfEmail FROM Contact WHERE Id = :c1Id];
        System.assertEquals(a1Id, c1.AccountId);
        System.assertEquals('test1', c1.LastName);
        System.assertEquals('test@test.com', c1.Email);
        System.assertEquals(false, c1.DoNotCall);
        System.assertEquals(true, c1.HasOptedOutOfEmail);
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c2Id].isEmpty());
    }
    
    @isTest
    static void test_no_victim_children() {
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = 'test1'].Id;
        
        delete [SELECT Id FROM Contact WHERE AccountId = :a2Id];
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = a2Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals('Merged', p.Status__c);
        
        Account a1 = [SELECT Id, Name, Website FROM Account WHERE Id = :a1Id];
        System.assertEquals('test1', a1.Name);
        System.assertEquals('www.test2.com', a1.Website);
        
        System.assert([SELECT Id FROM Account WHERE Id = :a2Id].isEmpty());
        
        Contact c1 = [SELECT Id, AccountId, LastName, Email, DoNotCall, HasOptedOutOfEmail FROM Contact WHERE Id = :c1Id];
        System.assertEquals(a1Id, c1.AccountId);
        System.assertEquals('test1', c1.LastName);
        System.assertEquals(null, c1.Email);
        System.assertEquals(false, c1.DoNotCall);
        System.assertEquals(false, c1.HasOptedOutOfEmail);
    }
    
    @isTest
    static void test_keep_most_recent_value() {
        
        Id pId = Schema.SObjectType.Object_Merge_Handler__c.getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        
        Object_Merge_Handler__c h1 = new Object_Merge_Handler__c(Name = 'Account', Active__c = true, RecordTypeId = pId);
        Object_Merge_Handler__c h2 = new Object_Merge_Handler__c(Name = 'Account', Active__c = true, RecordTypeId = pId);
        insert new List<Object_Merge_Handler__c>{h1, h2};
        
        Object_Merge_Field__c f1 = new Object_Merge_Field__c(Name = 'Name', Object_Merge_Handler__c = h1.Id, Active__c = true);
        Object_Merge_Field__c f2 = new Object_Merge_Field__c(Name = 'Name', Object_Merge_Handler__c = h2.Id, Active__c = true);
        insert new List<Object_Merge_Field__c>{f1, f2};
        
        Datetime createdDate = System.now().addHours(-1);
        
        Test.setCreatedDate(h1.Id, createdDate);
        Test.setCreatedDate(h2.Id, createdDate);
        Test.setCreatedDate(f1.Id, createdDate);
        Test.setCreatedDate(f2.Id, createdDate);
        
        h2.Active__c = false;
        update h2;
        
        f2.Active__c = false;
        update f2;
        
        insert new Object_Merge_Handler__History(ParentId = h2.Id, Field = 'Active__c');
        insert new Object_Merge_Field__History(ParentId = f2.Id, Field = 'Active__c');
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = h1.Id, Victim_ID__c = h2.Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals('Merged', p.Status__c);
        
        h1 = [SELECT Id, Active__c FROM Object_Merge_Handler__c WHERE Id = :h1.Id];
        System.assertEquals(false, h1.Active__c);
        
        System.assert([SELECT Id FROM Object_Merge_Handler__c WHERE Id = :h2.Id].isEmpty());
        
        f1 = [SELECT Id, Active__c FROM Object_Merge_Field__c WHERE Id = :f1.Id];
        System.assertEquals(false, f1.Active__c);
        
        System.assert([SELECT Id FROM Object_Merge_Field__c WHERE Id = :f2.Id].isEmpty());
    }
    
    @isTest
    static void test_handle_users_1() {
        
        Id c4Id = [SELECT Id FROM Contact WHERE LastName = 'test4'].Id;
        Id c5Id = [SELECT Id FROM Contact WHERE LastName = 'test5'].Id;
        
        Boolean testUserMerge = ObjectMergeUtility.portalEnabled && Database.countQuery('SELECT count() FROM User WHERE ContactId = :c4Id') == 1;
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = c4Id, Victim_ID__c = c5Id);
        
        Test.startTest();
        
        insert p;
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals(testUserMerge ? 'Processing' : 'Merged', p.Status__c);
    }
    
    @isTest
    static void test_handle_users_2() {
        
        Id c4Id = [SELECT Id FROM Contact WHERE LastName = 'test4'].Id;
        Id c5Id = [SELECT Id FROM Contact WHERE LastName = 'test5'].Id;
        
        Boolean testUserMerge = ObjectMergeUtility.portalEnabled && Database.countQuery('SELECT count() FROM User WHERE ContactId = :c4Id') == 1;
        
        Set<Id> userIdsToDeactivate = new Set<Id>();
        Map<Id, Id> ownerIdMap = new Map<Id, Id>();
        if (testUserMerge) {
            
            Id u4Id = Database.query('SELECT Id FROM User WHERE ContactId = :c4Id')[0].Id;
            Id u5Id = Database.query('SELECT Id FROM User WHERE ContactId = :c5Id')[0].Id;
            
            userIdsToDeactivate.add(u5Id);
            ownerIdMap.put(u5Id, u4Id);
            
        } else {
            userIdsToDeactivate.add(UserInfo.getUserId());
        }
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = c4Id, Victim_ID__c = c5Id);
        
        ObjectMergePairTriggerHandler.disable();
        insert p;
        ObjectMergePairTriggerHandler.enable();
        
        Test.startTest();
        
        ObjectMergeHandleUsers cls = new ObjectMergeHandleUsers(new Set<Id>{p.Id}, userIdsToDeactivate, ownerIdMap);
        cls.execute(true);
        
        Test.stopTest();
    }
    
    @isTest
    static void test_handle_users_3() {
        
        Id c4Id = [SELECT Id FROM Contact WHERE LastName = 'test4'].Id;
        Id c6Id = [SELECT Id FROM Contact WHERE LastName = 'test6'].Id;
        
        Boolean testUserMerge = ObjectMergeUtility.portalEnabled && Database.countQuery('SELECT count() FROM User WHERE ContactId = :c4Id') == 1;
        
        Id u4Id;
        Map<Id, Id> ownerIdMap = new Map<Id, Id>();
        
        if (testUserMerge) {
            
            u4Id = Database.query('SELECT Id FROM User WHERE ContactId = :c4Id')[0].Id;
            ownerIdMap.put(UserInfo.getUserId(), u4Id);
        }
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = c4Id, Victim_ID__c = c6Id);
        
        ObjectMergePairTriggerHandler.disable();
        insert p;
        ObjectMergePairTriggerHandler.enable();
        
        Test.startTest();
        
        System.enqueueJob(new ObjectMergeHandleUsers(new Set<Id>{p.Id}, new Set<Id>(), ownerIdMap));
        
        Test.stopTest();
        
        Contact c4 = [SELECT Id, LastName, (SELECT Id, OwnerId FROM Tasks) FROM Contact WHERE Id = :c4Id];
        System.assertEquals('test4', c4.LastName);
        
        System.assert([SELECT Id FROM Contact WHERE Id = :c6Id].isEmpty());
        
        if (testUserMerge) {
            
            System.assertEquals(1, c4.Tasks.size());
            System.assertEquals(u4Id, c4.Tasks[0].OwnerId);
        }
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals('Merged', p.Status__c);
    }
    
    @isTest
    static void test_handle_users_4() {
        
        Id c4Id = [SELECT Id FROM Contact WHERE LastName = 'test4'].Id;
        Id c5Id = [SELECT Id FROM Contact WHERE LastName = 'test5'].Id;
        
        Boolean testUserMerge = ObjectMergeUtility.portalEnabled && Database.countQuery('SELECT count() FROM User WHERE ContactId = :c4Id') == 1;
        
        Object_Merge_Pair__c p = new Object_Merge_Pair__c(Master_ID__c = c4Id, Victim_ID__c = c5Id, Status__c = 'Processing');
        
        ObjectMergePairTriggerHandler.disable();
        insert p;
        ObjectMergePairTriggerHandler.enable();
        
        Test.startTest();
        
        ObjectMergeHandleUsers.handleUsers(new List<Object_Merge_Pair__c>{p});
        
        if (!ObjectMergeUtility.portalEnabled)
        	ObjectMergeHandleUsers.setUserFieldsToDeactivate(new List<User>{new User()});
        
        Test.stopTest();
        
        p = [SELECT Id, Status__c FROM Object_Merge_Pair__c WHERE Id = :p.Id];
        System.assertEquals(testUserMerge ? 'Processing' : 'Merged', p.Status__c);
    }
    
    @isTest
    static void test_errors_1() {
        
        Id a1Id = [SELECT Id FROM Account WHERE Name = 'test1'].Id;
        Id a2Id = [SELECT Id FROM Account WHERE Name = 'test2'].Id;
        Id c1Id = [SELECT Id FROM Contact WHERE LastName = 'test1'].Id;
        
        Object_Merge_Pair__c p1 = new Object_Merge_Pair__c(Status__c = 'Retry', Master_ID__c = a1Id, Victim_ID__c = a2Id);
        Object_Merge_Pair__c p2 = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = c1Id);
        Object_Merge_Pair__c p3 = new Object_Merge_Pair__c(Master_ID__c = '00T0H00003uKOXt', Victim_ID__c = '00T0H00003uKOXt');
        Object_Merge_Pair__c p4 = new Object_Merge_Pair__c(Master_ID__c = a1Id, Victim_ID__c = '0011900000xbYvA');
        
        Test.startTest();
        
        insert new List<Object_Merge_Pair__c>{p1, p2, p3, p4};
        
        Test.stopTest();
        
        p1 = [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p1.Id];
        p2 = [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p2.Id];
        p3 = [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p3.Id];
        p4 = [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p4.Id];
        
        System.assertEquals('Error', p1.Status__c);
        System.assertEquals('Error', p2.Status__c);
        System.assertEquals('Error', p3.Status__c);
        System.assertEquals('Error', p4.Status__c);
        
        System.assertEquals('Invalid status', p1.Error_Reason__c);
        System.assertEquals('Invalid Master/Victim ID pair', p2.Error_Reason__c);
        System.assertEquals('Object Merge Handler not found', p3.Error_Reason__c);
        System.assertEquals('Master and/or victim not found', p4.Error_Reason__c);
    }
    
    @isTest
    static void test_errors_2() {
        
        Object_Merge_Field__c activeField = [SELECT Id FROM Object_Merge_Field__c WHERE Object_Merge_Handler__r.Name = 'Object_Merge_Handler__c' AND Name = 'Active__c'];
        
        activeField.Treat_False_as_Null__c = true;
        
        update activeField;
        
        Id parentRtId = Schema.SObjectType.Object_Merge_Handler__c.getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        
        Object_Merge_Handler__c h1 = new Object_Merge_Handler__c(Name = 'not_an_object', Active__c = false, RecordTypeId = parentRtId);
        Object_Merge_Handler__c h2 = new Object_Merge_Handler__c(Name = 'Task', Active__c = true, RecordTypeId = parentRtId);
        
        insert new List<Object_Merge_Handler__c>{h1, h2};
        
        Object_Merge_Pair__c p1 = new Object_Merge_Pair__c(Master_ID__c = 'test', Victim_ID__c = 'test');
        Object_Merge_Pair__c p2 = new Object_Merge_Pair__c(Master_ID__c = 'test', Victim_ID__c = 'test');
        Object_Merge_Pair__c p3 = new Object_Merge_Pair__c(Master_ID__c = h1.Id, Victim_ID__c = h2.Id);
        
        insert new List<Object_Merge_Pair__c>{p1, p2};
        
        p1.Status__c = 'Retry';
        p1.Master_ID__c = p2.Id;
        p1.Victim_ID__c = p1.Id;
        
        Test.startTest();
        
        update p1;
        insert p3;
        
        Test.stopTest();
        
        p1 = [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p1.Id];
        p3 = [SELECT Id, Status__c, Error_Reason__c FROM Object_Merge_Pair__c WHERE Id = :p3.Id];
        
        System.assertEquals('Error', p1.Status__c);
        System.assertEquals('Error performing DML', p1.Error_Reason__c);
        
        System.assertEquals('Error', p3.Status__c);
        System.assertEquals('Error performing DML', p3.Error_Reason__c);
    }
    
    @testSetup
    static void setup() {
        
        Id portalAccountOwnerId = UserInfo.getUserId();
        Boolean userRoleFound = UserInfo.getUserRoleId() != null;
        if (!userRoleFound) {
            for (User u:[SELECT Id FROM User WHERE IsActive = true AND UserRoleId != null AND UserType = 'Standard' LIMIT 1]) {
                userRoleFound = true;
            	portalAccountOwnerId = u.Id;
            }
        }
        
        Account a1 = new Account(Name = 'test1');
        Account a2 = new Account(Name = 'test2', Website = 'www.test2.com');
        Account a3 = new Account(Name = 'test3', OwnerId = portalAccountOwnerId);
        Account a4 = new Account(Name = 'test4', OwnerId = portalAccountOwnerId);
        Account a5 = new Account(Name = 'test5', OwnerId = portalAccountOwnerId);
        insert new List<Account>{a1, a2, a3, a4, a5};
        
        Contact c1 = new Contact(AccountId = a1.Id, LastName = 'test1', FirstName = 'test');
        Contact c2 = new Contact(AccountId = a2.Id, LastName = 'test2', FirstName = 'test', Email = 'test@test.com', DoNotCall = true, HasOptedOutOfEmail = true);
        Contact c3 = new Contact(AccountId = a2.Id, LastName = 'test3', FirstName = 'not_test');
        Contact c4 = new Contact(AccountId = a3.Id, LastName = 'test4', FirstName = 'test');
        Contact c5 = new Contact(AccountId = a4.Id, LastName = 'test5', FirstName = 'test');
        Contact c6 = new Contact(AccountId = a5.Id, LastName = 'test6', FirstName = 'test');
        insert new List<Contact>{c1, c2, c3, c4, c5, c6};
        
        if (userRoleFound && ObjectMergeUtility.portalEnabled) {
            
            Datetime orgCreatedDate = [SELECT Id, CreatedDate FROM Organization LIMIT 1].CreatedDate.addHours(1);
            
            Id profileId;
        	for (Profile p:[SELECT Id FROM Profile WHERE UserType IN ('CSPLitePortal', 'CustomerSuccess', 'PowerCustomerSuccess') AND CreatedDate > :orgCreatedDate ORDER BY CreatedDate DESC LIMIT 1])
            	profileId = p.Id;
            
            if (profileId != null) {
                
        		User u4 = new User(Username = 'test_object_merge_4@test.com', ProfileId = profileId, Alias = 'test4', Email = 'test@test.com', EmailEncodingKey = 'UTF-8', FirstName = 'test4', LastName = 'test4', IsActive = true, TimeZoneSidKey = 'America/Chicago', LocaleSidKey = 'en_US', LanguageLocaleKey = 'en_US');
        		User u5 = new User(Username = 'test_object_merge_5@test.com', ProfileId = profileId, Alias = 'test5', Email = 'test@test.com', EmailEncodingKey = 'UTF-8', FirstName = 'test5', LastName = 'test5', IsActive = true, TimeZoneSidKey = 'America/Chicago', LocaleSidKey = 'en_US', LanguageLocaleKey = 'en_US');
        		
                u4.put('ContactId', c4.Id);
                u4.put('CommunityNickname', 'test4');
                
                u5.put('ContactId', c5.Id);
                u5.put('CommunityNickname', 'test5');
                
                insert new List<User>{u4, u5};
                
                insert (new Task(WhoId = c6.Id, OwnerId = UserInfo.getUserId()));
            }
        }
        
        Id pId = Schema.SObjectType.Object_Merge_Handler__c.getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        Id cId = Schema.SObjectType.Object_Merge_Handler__c.getRecordTypeInfosByDeveloperName().get('Child_Handler').getRecordTypeId();
        
        Object_Merge_Handler__c ph1 = new Object_Merge_Handler__c(Name = 'Account', Active__c = true, RecordTypeId = pId);
        Object_Merge_Handler__c ph2 = new Object_Merge_Handler__c(Name = 'Contact', Active__c = true, RecordTypeId = pId);
        Object_Merge_Handler__c ph3 = new Object_Merge_Handler__c(Name = 'Object_Merge_Handler__c', RecordTypeId = pId);
        Object_Merge_Handler__c ph4 = new Object_Merge_Handler__c(Name = 'Object_Merge_Pair__c', RecordTypeId = pId);
        insert new List<Object_Merge_Handler__c>{ph1, ph2, ph3, ph4};
        
        Object_Merge_Handler__c ch1 = new Object_Merge_Handler__c(Name = 'Contact', Parent_Handler__c = ph1.Id, Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Delete Victim', Active__c = true, RecordTypeId = cId);
        Object_Merge_Handler__c ch2 = new Object_Merge_Handler__c(Name = 'Task', Parent_Handler__c = ph2.Id, Object_Lookup_Field_API_Name__c = 'WhoId', Standard_Action__c = 'Move Victim', Active__c = true, RecordTypeId = cId);
        Object_Merge_Handler__c ch3 = new Object_Merge_Handler__c(Name = 'Object_Merge_Field__c', Parent_Handler__c = ph3.Id, Object_Lookup_Field_API_Name__c = 'Object_Merge_Handler__c', Standard_Action__c = 'Move Victim', Merge_Action__c = 'Keep Master', Active__c = true, RecordTypeId = cId);
        
        List<Object_Merge_Handler__c> childHandlers = new List<Object_Merge_Handler__c>{ch1, ch2, ch3};
        
        if (ObjectMergeUtility.portalEnabled)
        	childHandlers.add(new Object_Merge_Handler__c(Name = 'User', Parent_Handler__c = ph2.Id, Object_Lookup_Field_API_Name__c = 'ContactId', Standard_Action__c = 'Delete Victim', Active__c = true, RecordTypeId = cId));
        
        insert childHandlers;
        
        Object_Merge_Field__c f1 = new Object_Merge_Field__c(Name = 'Name', Use_for_Matching__c = false, Object_Merge_Handler__c = ph1.Id, Active__c = true);
        Object_Merge_Field__c f2 = new Object_Merge_Field__c(Name = 'Website', Use_for_Matching__c = false, Object_Merge_Handler__c = ph1.Id, Active__c = true);
        Object_Merge_Field__c f3 = new Object_Merge_Field__c(Name = 'LastName', Use_for_Matching__c = false, Object_Merge_Handler__c = ch1.Id, Active__c = true);
        Object_Merge_Field__c f4 = new Object_Merge_Field__c(Name = 'FirstName', Use_for_Matching__c = true, Object_Merge_Handler__c = ch1.Id, Active__c = true);
        Object_Merge_Field__c f5 = new Object_Merge_Field__c(Name = 'Email', Use_for_Matching__c = false, Object_Merge_Handler__c = ch1.Id, Active__c = true);
        Object_Merge_Field__c f6 = new Object_Merge_Field__c(Name = 'DoNotCall', Use_for_Matching__c = false, Object_Merge_Handler__c = ch1.Id, Active__c = true);
        Object_Merge_Field__c f7 = new Object_Merge_Field__c(Name = 'HasOptedOutOfEmail', Use_for_Matching__c = false, Object_Merge_Handler__c = ch1.Id, Active__c = true, Treat_False_as_Null__c = true);
        Object_Merge_Field__c f8 = new Object_Merge_Field__c(Name = 'Active__c', Use_for_Matching__c = false, Object_Merge_Handler__c = ph3.Id, Active__c = true, Keep_Most_Recent_Value__c = true);
        Object_Merge_Field__c f9 = new Object_Merge_Field__c(Name = 'Name', Use_for_Matching__c = true, Object_Merge_Handler__c = ch3.Id, Active__c = true);
        Object_Merge_Field__c f10 = new Object_Merge_Field__c(Name = 'Active__c', Use_for_Matching__c = false, Object_Merge_Handler__c = ch3.Id, Active__c = true, Keep_Most_Recent_Value__c = true);
        insert new List<Object_Merge_Field__c>{f1, f2, f3, f4, f5, f6, f7, f8, f9, f10};
    }
}