public with sharing class ObjectMergeValidator {

    //Checks to make sure name of handler is in the org
    public static void validateObjectMergeHandlers ( List<Object_Merge_Handler__c> omhs ) {

        Set<String> orgSobjects = Schema.getGlobalDescribe().keySet();
        system.debug(orgSobjects);
        //Loop through all handlers to find which aren't valid based on their objects absence in the org
        for ( Object_Merge_Handler__c omh : omhs )
            if ( !orgSobjects.contains( omh.Name.toLowerCase() ) )
                omh.addError( 'This Object Merge handler is invalid because the sObject does not exist. Check to make sure the API name is valid.' );

    }

    //Ensures that the name of the field handler is on the parent object
    public static void validateFieldHandlers ( List<Object_Merge_Field__c> omfs ) {

        List<Id> omhs = new List<Id>();
        Map<Id, Set<String>> fieldsByOmh = new Map<Id, Set<String>>();
        Map<String, Schema.SObjectType> orgSobjects = Schema.getGlobalDescribe();

        //Collect list of handlers
        for ( Object_Merge_Field__c omf : omfs )
            omhs.add( omf.Object_Merge_Handler__c );

        //Get list of fields for each handler
        for ( Object_Merge_Handler__c omh : [SELECT Id, Name FROM Object_Merge_Handler__c WHERE Id IN :omhs ] )
            fieldsByOmh.put( omh.Id, orgSobjects.get( omh.Name.toLowerCase() ).getDescribe().fields.getMap().keySet() );

        //Loop through all fields to find which aren't valid based on their absence on the parent object
        for ( Object_Merge_Field__c omf : omfs )
            if ( !fieldsByOmh.get(omf.Object_Merge_Handler__c).contains( omf.Name.toLowerCase() ) )
                omf.addError( 'This Object Merge Field is invalid because the field does on the handler\'s object. Check to make sure the API name is valid.' );

    }

}
