trigger objectMergeHandlerTrigger on Object_Merge_Handler__c ( before insert, before update) {

    ObjectMergeValidator.validateObjectMergeHandlers( TRIGGER.NEW );
    
}