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
private class ObjectMergeValidatorTest {
	
    @isTest
    static void test_validate_object_merge_handlers_insert() {
		
        Id parentHandlerId = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Account'].Id;
        Id childRtId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Child_Handler').getRecordTypeId();
        
        List<Object_Merge_Handler__c> handlers = new List<Object_Merge_Handler__c>();
        
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Not_an_Object', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Not_an_Object', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = false, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'Not_a_Field', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'Not_a_Field', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = false, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'OwnerId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'OwnerId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = false, RecordTypeId = childRtId));
		
        Test.startTest();
        
        List<Database.SaveResult> results = Database.insert(handlers, false);
        
        Test.stopTest();
        
        System.assertEquals(true, results[0].isSuccess());
        System.assertEquals(false, results[1].isSuccess());
        System.assertEquals(true, results[2].isSuccess());
        System.assertEquals(false, results[3].isSuccess());
        System.assertEquals(true, results[4].isSuccess());
        System.assertEquals(false, results[5].isSuccess());
        System.assertEquals(true, results[6].isSuccess());
    }
    
    @isTest
    static void test_validate_object_merge_handlers_update() {
		
        Id parentHandlerId = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Account'].Id;
        Id childRtId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Child_Handler').getRecordTypeId();
        
        List<Object_Merge_Handler__c> handlers = new List<Object_Merge_Handler__c>();
        
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        handlers.add(new Object_Merge_Handler__c(Name = 'Contact', Object_Lookup_Field_API_Name__c = 'AccountId', Standard_Action__c = 'Move Victim', Parent_Handler__c = parentHandlerId, Active__c = true, RecordTypeId = childRtId));
        
        insert handlers;
        
        handlers[0].Name = 'Task';
        handlers[0].Object_Lookup_Field_API_Name__c = 'WhatId';
        
        handlers[1].Name = 'Not_an_Object';
        handlers[2].Name = 'Not_an_Object';
        handlers[2].Active__c = false;
        
        handlers[3].Object_Lookup_Field_API_Name__c = 'Not_a_Field';
        handlers[4].Object_Lookup_Field_API_Name__c = 'Not_a_Field';
        handlers[4].Active__c = false;
        
        handlers[5].Object_Lookup_Field_API_Name__c = 'OwnerId';
        handlers[6].Object_Lookup_Field_API_Name__c = 'OwnerId';
        handlers[6].Active__c = false;
		
        Test.startTest();
        
        List<Database.SaveResult> results = Database.update(handlers, false);
        
        Test.stopTest();
        
        System.assertEquals(true, results[0].isSuccess());
        System.assertEquals(false, results[1].isSuccess());
        System.assertEquals(true, results[2].isSuccess());
        System.assertEquals(false, results[3].isSuccess());
        System.assertEquals(true, results[4].isSuccess());
        System.assertEquals(false, results[5].isSuccess());
        System.assertEquals(true, results[6].isSuccess());
    }
    
    @isTest
    static void test_validate_object_merge_fields_insert() {
		
        Id parentHandlerId = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Account'].Id;
		
        List<Object_Merge_Field__c> fields = new List<Object_Merge_Field__c>();
        
        fields.add(new Object_Merge_Field__c(Name = 'Name', Object_Merge_Handler__c = parentHandlerId, Active__c = true));
        fields.add(new Object_Merge_Field__c(Name = 'Not_a_Field', Object_Merge_Handler__c = parentHandlerId, Active__c = true));
        fields.add(new Object_Merge_Field__c(Name = 'Not_a_Field', Object_Merge_Handler__c = parentHandlerId, Active__c = false));
		
        Test.startTest();
        
        List<Database.SaveResult> results = Database.insert(fields, false);
        
        Test.stopTest();
        
        System.assertEquals(true, results[0].isSuccess());
        System.assertEquals(false, results[1].isSuccess());
        System.assertEquals(true, results[2].isSuccess());
    }
    
    @isTest
    static void test_validate_object_merge_fields_update() {
		
        Id parentHandlerId = [SELECT Id FROM Object_Merge_Handler__c WHERE Name = 'Account'].Id;
		
        List<Object_Merge_Field__c> fields = new List<Object_Merge_Field__c>();
        
        fields.add(new Object_Merge_Field__c(Name = 'Name', Object_Merge_Handler__c = parentHandlerId, Active__c = true));
        fields.add(new Object_Merge_Field__c(Name = 'Name', Object_Merge_Handler__c = parentHandlerId, Active__c = true));
        fields.add(new Object_Merge_Field__c(Name = 'Name', Object_Merge_Handler__c = parentHandlerId, Active__c = true));
        
        insert fields;
        
        fields[0].Name = 'Website';
        fields[1].Name = 'Not_a_Field';
        fields[2].Name = 'Not_a_Field';
        fields[2].Active__c = false;
        
        Test.startTest();
        
        List<Database.SaveResult> results = Database.update(fields, false);
        
        Test.stopTest();
        
        System.assertEquals(true, results[0].isSuccess());
        System.assertEquals(false, results[1].isSuccess());
        System.assertEquals(true, results[2].isSuccess());
    }
    
    @testSetup
    static void setup() {
        
        Id parentRtId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        
        insert (new Object_Merge_Handler__c(Name = 'Account', Active__c = true, RecordTypeId = parentRtId));
    }
}