@isTest
public class ObjectMergeValidatorTest {

    @isTest
    private static void testInsertInvalidField() {

        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        //Start by creating the object merge handler
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c (
            Active__c       = true,
            Name            = 'Account',
            RecordTypeId    = parentHandlerId
        );
        insert omh;

        Object_Merge_Field__c omf = new Object_Merge_Field__c (
            Active__c               = true,
            Object_Merge_Handler__c = omh.Id,
            Name                    = 'Not a valid field name'
        );

        Test.startTest();
            try{
                insert omf;
                system.assert( false, 'Object Merge field with illegal name was inserted without proper validation');
            } catch (Exception e) {

            }
        Test.stopTest();

    }

    @isTest
    private static void testUpdateInvalidField() {

        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        //Start by creating the object merge handler
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c (
            Active__c       = true,
            Name            = 'Account',
            RecordTypeId    = parentHandlerId
        );
        insert omh;

        Object_Merge_Field__c omf = new Object_Merge_Field__c (
            Active__c               = true,
            Object_Merge_Handler__c = omh.Id,
            Name                    = 'Name'
        );
        insert omf;
        omf.Name = 'Not a valid field name';

        Test.startTest();
            try{
                update omf;
                system.assert( false, 'Object Merge field with illegal name was updated without proper validation');
            } catch (Exception e) {

            }
        Test.stopTest();

    }

    @isTest
    private static void testInsertInvalidHandler() {

        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        //Start by creating the object merge handler
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c (
            Active__c       = true,
            Name            = 'Not a valid object name',
            RecordTypeId    = parentHandlerId
        );

        Test.startTest();
            try{
                insert omh;
                system.assert( false, 'Object Merge field with illegal name was updated without proper validation');
            } catch (Exception e) {

            }
        Test.stopTest();
       

    }

    @isTest
    private static void testUpdateInvalidHandler() {

        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        //Start by creating the object merge handler
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c (
            Active__c       = true,
            Name            = 'Account',
            RecordTypeId    = parentHandlerId
        );
        insert omh;
        omh.Name = 'Not a valid object name';

        Test.startTest();
            try{
                update omh;
                system.assert( false, 'Object Merge field with illegal name was updated without proper validation');
            } catch (Exception e) {

            }
        Test.stopTest();

    }

    @isTest
    private static void testInsertValidField() {

        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        //Start by creating the object merge handler
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c (
            Active__c       = true,
            Name            = 'Account',
            RecordTypeId    = parentHandlerId
        );
        insert omh;

        Object_Merge_Field__c omf = new Object_Merge_Field__c (
            Active__c               = true,
            Object_Merge_Handler__c = omh.Id,
            Name                    = 'Name'
        );

        Test.startTest();
            insert omf;
        Test.stopTest();

    }

    @isTest
    private static void testUpdateValidField() {

        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        //Start by creating the object merge handler
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c (
            Active__c       = true,
            Name            = 'Account',
            RecordTypeId    = parentHandlerId
        );
        insert omh;

        Object_Merge_Field__c omf = new Object_Merge_Field__c (
            Active__c               = true,
            Object_Merge_Handler__c = omh.Id,
            Name                    = 'Name'
        );
        insert omf;
        omf.Name = 'Id';

        Test.startTest();
            update omf;
        Test.stopTest();

    }

    @isTest
    private static void testInsertValidHandler() {

        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        //Start by creating the object merge handler
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c (
            Active__c       = true,
            Name            = 'Account',
            RecordTypeId    = parentHandlerId
        );

        Test.startTest();
            insert omh;
        Test.stopTest();
       

    }

    @isTest
    private static void testUpdateValidHandler() {

        Id parentHandlerId = Object_Merge_Handler__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Parent_Handler').getRecordTypeId();
        //Start by creating the object merge handler
        Object_Merge_Handler__c omh = new Object_Merge_Handler__c (
            Active__c       = true,
            Name            = 'Account',
            RecordTypeId    = parentHandlerId
        );
        insert omh;
        omh.Name = 'Contact';

        Test.startTest();
            update omh;
        Test.stopTest();

    }

}
