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
@isTest
private class ObjectMergeValidatorTest {
	
    @isTest
    static void testInsertHandlers() {
		
        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        
        List<Object_Merge_Handler__c> handlers = new List<Object_Merge_Handler__c>();
        handlers.add(new Object_Merge_Handler__c(Active__c = true, Name = 'Account', RecordTypeId = parentHandlerId));
        handlers.add(new Object_Merge_Handler__c(Active__c = true, Name = 'Not a valid object name', RecordTypeId = parentHandlerId));
		
        Test.startTest();
        
        List<Database.SaveResult> results = Database.insert(handlers, false);
        
        Test.stopTest();
        
        System.assert(results[0].isSuccess(), 'Object Merge Handler with legal name was not inserted');
        System.assert(!results[1].isSuccess(), 'Object Merge Handler with illegal name was inserted without proper validation');
    }
    
    @isTest
    static void testUpdateHandlers() {
		
        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        
        List<Object_Merge_Handler__c> handlers = new List<Object_Merge_Handler__c>();
        handlers.add(new Object_Merge_Handler__c(Active__c = true, Name = 'Account', RecordTypeId = parentHandlerId));
        handlers.add(new Object_Merge_Handler__c(Active__c = true, Name = 'Account', RecordTypeId = parentHandlerId));
        insert handlers;
        
        handlers[0].Name = 'Contact';
        handlers[1].Name = 'Not a valid object name';
		
        Test.startTest();
        
        List<Database.SaveResult> results = Database.update(handlers, false);
        
        Test.stopTest();
        
        System.assert(results[0].isSuccess(), 'Object Merge Handler with legal name was not updated');
        System.assert(!results[1].isSuccess(), 'Object Merge Handler with illegal name was updated without proper validation');
    }
    
    @isTest
    static void testInsertFields() {
		
        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c(Active__c = true, Name = 'Account', RecordTypeId = parentHandlerId);
        insert omh;
		
        List<Object_Merge_Field__c> fields = new List<Object_Merge_Field__c>();
        fields.add(new Object_Merge_Field__c(Active__c = true, Object_Merge_Handler__c = omh.Id, Name = 'Name'));
        fields.add(new Object_Merge_Field__c(Active__c = true, Object_Merge_Handler__c = omh.Id, Name = 'Not a valid field name'));
		
        Test.startTest();
        
        List<Database.SaveResult> results = Database.insert(fields, false);
        
        Test.stopTest();
        
        System.assert(results[0].isSuccess(), 'Object Merge Field with legal name was not inserted');
        System.assert(!results[1].isSuccess(), 'Object Merge Field with illegal name was inserted without proper validation');
    }
    
    @isTest
    static void testUpdateFields() {
		
        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c(Active__c = true, Name = 'Account', RecordTypeId = parentHandlerId);
        insert omh;
		
        List<Object_Merge_Field__c> fields = new List<Object_Merge_Field__c>();
        fields.add(new Object_Merge_Field__c(Active__c = true, Object_Merge_Handler__c = omh.Id, Name = 'Name'));
        fields.add(new Object_Merge_Field__c(Active__c = true, Object_Merge_Handler__c = omh.Id, Name = 'Name'));
		insert fields;
        
        fields[0].Name = 'Description';
        fields[1].Name = 'Not a valid field name';
        
        Test.startTest();
        
        List<Database.SaveResult> results = Database.update(fields, false);
        
        Test.stopTest();
        
        System.assert(results[0].isSuccess(), 'Object Merge Field with legal name was not updated');
        System.assert(!results[1].isSuccess(), 'Object Merge Field with illegal name was updated without proper validation');
    }
}