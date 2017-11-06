trigger ObjectMergePairTrigger on Object_Merge_Pair__c (before insert, before update) {
	ObjectMergePairTriggerHandler.MergeObjects(Trigger.new, Trigger.isUpdate);
}