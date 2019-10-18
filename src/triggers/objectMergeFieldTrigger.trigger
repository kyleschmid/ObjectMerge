trigger objectMergeFieldTrigger on Object_Merge_Field__c (before insert, before update) {

    ObjectMergeValidator.validateFieldHandlers( TRIGGER.NEW );

}