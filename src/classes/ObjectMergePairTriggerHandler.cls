/*
    BSD 3-Clause License
    
    Copyright (c) 2017, Kyle Schmid, Huron Consulting Group
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
public class ObjectMergePairTriggerHandler {
	
    public static void MergeObjects(List<Object_Merge_Pair__c> pairs, Boolean isUpdate) {
        
        // Get set of object prefixes and check for valid status/IDs
        Set<String> prefixes = new Set<String>();
        for (Object_Merge_Pair__c p:pairs) {
            
            p.Merge_Date__c = System.NOW(); // Set merge date to now
            
            // Check for valid status
            if ((!isUpdate && String.isNotBlank(p.Status__c)) || (isUpdate && (String.isBlank(p.Status__c) || !p.Status__c.equals('Retry')))) {
                addError(p, 'Invalid status');
                continue;
            }
            
            p.Status__c = null;
            p.Error_Reason__c = null;
            
            // Check for valid IDs and add prefix to set
            try {
                if (Id.valueOf(p.Master_ID__c).getSobjectType() != Id.valueOf(p.Victim_ID__c).getSobjectType())
                    throw new ObjectMergePairException();
                
            } catch (Exception e) {
                addError(p, 'Invalid Master/Victim ID pair');
            }
            
            prefixes.add(String.valueOf(Id.valueOf(p.Master_ID__c)).substring(0, 3));
        }
        
        // Get prefix-name map
        Map<String, String> prefixMap = new Map<String, String>();
        for (Schema.SObjectType t:Schema.getGlobalDescribe().values()) {
            Schema.DescribeSObjectResult d = t.getDescribe();
            if (prefixes.contains(d.getKeyPrefix()))
                prefixMap.put(d.getKeyPrefix(), d.getName().toLowerCase());
        }
        
        // Group pairs by object type
        Map<String, List<Object_Merge_Pair__c>> pairMap = new Map<String, List<Object_Merge_Pair__c>>();
        for (Object_Merge_Pair__c p:pairs) {
            
            if (p.Status__c != null) continue; // Skip if error
            
            String objectName = prefixMap.get(String.valueOf(Id.valueOf(p.Master_ID__c)).substring(0, 3));
            
            // Add pair to object group
            if (!pairMap.containsKey(objectName))
                    pairMap.put(objectName, new List<Object_Merge_Pair__c>());
                pairMap.get(objectName).add(p);
        }
        
        // Get map of handlers grouped by object name
        Map<String, Object_Merge_Handler__c> handlers = new Map<String, Object_Merge_Handler__c>();
        for (Object_Merge_Handler__c h:[SELECT Id, Name, (SELECT Id, Name, Child_Relationship_Name__c, Object_Lookup_Field_API_Name__c, Standard_Action__c, Merge_Action__c, Clone_Reparented_Victim__c FROM Object_Merge_Handlers__r WHERE Active__c = :true ORDER BY Order_of_Execution__c ASC NULLS LAST) FROM Object_Merge_Handler__c WHERE RecordType.DeveloperName = :'Parent_Handler' AND Active__c = :true AND Name IN :pairMap.keySet()])
            handlers.put(h.Name.toLowerCase(), h);
        
        // Get maps of fields and matching fields grouped by parent id
        Map<Id, List<Object_Merge_Field__c>> fields = new Map<Id, List<Object_Merge_Field__c>>();
        Map<Id, List<Object_Merge_Field__c>> matchingFields = new Map<Id, List<Object_Merge_Field__c>>();
        for (Object_Merge_Field__c f:[SELECT Id, Object_Merge_Handler__c, Name, Use_for_Matching__c FROM Object_Merge_Field__c WHERE Active__c = :true AND ((Object_Merge_Handler__r.Active__c = :true AND Object_Merge_Handler__r.Name IN :pairMap.keySet()) OR (Object_Merge_Handler__r.Parent_Handler__r.Active__c = :true AND Object_Merge_Handler__r.Parent_Handler__r.Name IN :pairMap.keySet()))]) {
            
            // Add field to field map
            if (!fields.containsKey(f.Object_Merge_Handler__c))
                fields.put(f.Object_Merge_Handler__c, new List<Object_Merge_Field__c>());
            fields.get(f.Object_Merge_Handler__c).add(f);
            
            // Add matching field to map
            if (f.Use_for_Matching__c) {
                if (!matchingFields.containsKey(f.Object_Merge_Handler__c))
                    matchingFields.put(f.Object_Merge_Handler__c, new List<Object_Merge_Field__c>());
                matchingFields.get(f.Object_Merge_Handler__c).add(f);
            }
        }
        
        // Merge each type of object
        for (String objectName:pairMap.keySet()) {
            
            // Check to make sure we have a handler for this object
            if (!handlers.containsKey(objectName)) {
                addError(pairMap.get(objectName), 'Object Merge Handler not found');
                continue;
            }
            
            // Perform the merge
            doMerge(pairMap.get(objectName), handlers.get(objectName), fields, matchingFields);
        }
    }
	
	// Method to perform merge of a list of pairs of the same object type    
    private static void doMerge(List<Object_Merge_Pair__c> pairs, Object_Merge_Handler__c handler, Map<Id, List<Object_Merge_Field__c>> fields, Map<Id, List<Object_Merge_Field__c>> matchingFields) {
        
        // Get set of parent record ids
        Set<Id> parentIds = new Set<Id>();
        for (Object_Merge_Pair__c p:pairs) {
            if (p.Status__c != null) continue;
            parentIds.add(Id.valueOf(p.Master_ID__c));
            parentIds.add(Id.valueOf(p.Victim_ID__c));
        }
        
        // Query parent records
        Map<Id, SObject> parents;
        try {
            parents = new Map<Id, SObject>(Database.query(getQuery(handler, fields)));
        } catch (Exception e) {
            addError(pairs, 'Error running query');
            return;
        }
        
        // Lists of records to perform DML on
        List<SObject> recordsToUpdate = new List<SObject>();
        List<SObject> recordsToInsert = new List<SObject>();
        List<SObject> recordsToDelete = new List<SObject>();
        
        for (Object_Merge_Pair__c p:pairs) {
            
            // Skip if this pair has an error
            if (p.Status__c != null) continue;
            
            // Get master and victim records
            SObject master = parents.get(Id.valueOf(p.Master_ID__c));
            SObject victim = parents.get(Id.valueOf(p.Victim_ID__c));
            
            // Check to make sure we found master and victim
            if (master == null || victim == null) {
                addError(p, 'Master and/or victim not found');
                continue;
            }
            
            // Merge parents and add to DML lists
            if (mergeFields(fields.get(handler.Id), master, victim))
                recordsToUpdate.add(master);
            recordsToDelete.add(victim);
            
            // Handle child records
            for (Object_Merge_Handler__c h:handler.Object_Merge_Handlers__r) {
                
                // Get map of key for master children and corresponding children
                Map<String, SObject> masterChildren = new Map<String, SObject>();
                if (matchingFields.containsKey(h.Id))
                    for (SObject child:master.getSObjects(h.Child_Relationship_Name__c))
                    masterChildren.put(getChildCloneKey(matchingFields.get(h.Id), child), child);
                
                // Loop over victim children and handle
                for (SObject child:victim.getSObjects(h.Child_Relationship_Name__c)) {
                    
                    // String key to match to master children with
                    String key = getChildCloneKey(matchingFields.get(h.Id), child);
                    
                    // Handle if matched
                    if (String.isNotBlank(h.Merge_Action__c) && masterChildren.containsKey(key)) {
                        
                        SObject masterChild = masterChildren.get(key);
                        
                        if (h.Merge_Action__c.equals('Keep Master')) {
                            
                            // Merge victim child into matching master child
                            // Add master child to update list if updated
                            if (mergeFields(fields.get(h.Id), masterChildren.get(key), child))
                                recordsToUpdate.add(masterChildren.get(key));
                            
                            // Add victim child to delete list
                            recordsToDelete.add(child);
                            
                        } else if (h.Merge_Action__c.equals('Delete Duplicate')) {
                            
                            // Add victim child to delete list
                            recordsToDelete.add(child);
                            
                        } else if (h.Merge_Action__c.equals('Keep Oldest Created')) {
                            
                            // Master wins if created date is less than child created date
                            mergeChildren((Datetime)masterChild.get('CreatedDate') <= (Datetime)child.get('CreatedDate'), fields.get(h.Id), masterChild, child, recordsToInsert, recordsToUpdate, recordsToDelete, h.Object_Lookup_Field_API_Name__c, h.Clone_Reparented_Victim__c);
                            
                        } else if (h.Merge_Action__c.equals('Keep Newest Created')) {
                            
                            // Master wins if created date is greater than child created date
                            mergeChildren((Datetime)masterChild.get('CreatedDate') >= (Datetime)child.get('CreatedDate'), fields.get(h.Id), masterChild, child, recordsToInsert, recordsToUpdate, recordsToDelete, h.Object_Lookup_Field_API_Name__c, h.Clone_Reparented_Victim__c);
                            
                        } else if (h.Merge_Action__c.equals('Keep Last Modified')) {
                            
                            // Master wins if last modified date is greater than child created date
                            mergeChildren((Datetime)masterChild.get('LastModifiedDate') >= (Datetime)child.get('LastModifiedDate'), fields.get(h.Id), masterChild, child, recordsToInsert, recordsToUpdate, recordsToDelete, h.Object_Lookup_Field_API_Name__c, h.Clone_Reparented_Victim__c);
                        }
                        
                    } else if (h.Standard_Action__c.equals('Move Victim')) {
                        
                        // Reparent victim and add to udpate list
                        child.put(h.Object_Lookup_Field_API_Name__c, master.Id);
                        recordsToUpdate.add(child);
                        
                    } else if (h.Standard_Action__c.equals('Clone Victim')) {
                        
                        // Clone victims and add to insert list
                        SObject newChild = child.clone(false, true, false, false);
                        newChild.put(h.Object_Lookup_Field_API_Name__c, master.Id);
                        recordsToInsert.add(newChild);
                        
                        // Add original to delete list
                        recordsToDelete.add(child);
                        
                    } else if (h.Standard_Action__c.equals('Delete Victim')) {
                        
                        // Add victim to delete list
                        recordsToDelete.add(child);
                    }
                }
            }
        }
        
        // Get list of all update records that are not in the delete list
        Set<Id> recordsToDeleteIdsSet = new Set<Id>();
        List<SObject> recordsToDeleteList = new List<SObject>();
        for (SObject so:recordsToDelete) {
            if (!recordsToDeleteIdsSet.contains(so.Id)) {
            	recordsToDeleteIdsSet.add(so.Id);
                recordsToDeleteList.add(so);
            }
        }
        Set<Id> recordsToUpdateIds = new Set<Id>();
        List<SObject> recordsToUpdateList = new List<SObject>();
        for (SObject so:recordsToUpdate) {
            if (!recordsToDeleteIdsSet.contains(so.Id) && !recordsToUpdateIds.contains(so.Id)) {
            	recordsToUpdateIds.add(so.Id);
                recordsToUpdateList.add(so);
            }
        }
        
        System.Savepoint sp = Database.setSavepoint(); // Set savepoint to rollback on error;
        try {
            
            // Update records
            for (List<SObject> objects:groupSObjects(recordsToUpdateList, handler))
                update objects;
            
            // Insert records
            for (List<SObject> objects:groupSObjects(recordsToInsert, handler))
                insert objects;
            
            // Delete records and handle ENTITY_IS_DELETED error if records got deleted due to other DML
            for (List<SObject> objects:groupSObjects(recordsToDeleteList, handler))
                for (Database.DeleteResult dr:Database.delete(objects, false))
                    for (Database.Error er:dr.getErrors())
                        if (er.getStatusCode() != StatusCode.ENTITY_IS_DELETED)
                            throw new ObjectMergePairException();
            
        } catch (Exception e) {
            Database.rollback(sp);
            addError(pairs, 'Error performing DML');
        }
        
        // Set status to merged for all successful merges
        for (Object_Merge_Pair__c p:pairs)
            if (p.Status__c == null)
                p.Status__c = 'Merged';
    }
    
    // Returns string reporesentation of child object based on matching fields
    private static String getChildCloneKey(List<Object_Merge_Field__c> fields, SObject child) {
        String ret;
        if (fields != null) {
            SObject childClone = child.getSObjectType().newSObject();
            for (Object_Merge_Field__c f:fields) {
                childClone.put(f.Name, child.get(f.Name));
            }
            ret = String.valueOf(childClone);
        }
        return ret;
    }
    
    // Merges children and adds to update/delete lists
    private static void mergeChildren(Boolean masterWins, List<Object_Merge_Field__c> fields, SObject master, SObject victim, List<SObject> recordsToInsert, List<SObject> recordsToUpdate, List<SObject> recordsToDelete, String parentFieldAPIName, Boolean cloneReparentedVictim) {
        
        if (masterWins) {
            
            if (mergeFields(fields, master, victim))
            	recordsToUpdate.add(master);
            recordsToDelete.add(victim);
            
        } else {
            
            if (cloneReparentedVictim) {
                
                // Clone victim and merge master child into clone
                SObject newChild = victim.clone(false, true, false, false);
                newChild.put(parentFieldAPIName, master.get(parentFieldAPIName));
                mergeFields(fields, newChild, master);
                
                // Add clone to insert list and master/victim children to delete list
                recordsToInsert.add(newChild);
                recordsToDelete.add(victim);
                recordsToDelete.add(master);
            } else {
                
                // Merge master into victim and reparent victim
                mergeFields(fields, victim, master);
                victim.put(parentFieldAPIName, master.get(parentFieldAPIName));
                
                // Add master to delete list and victim to update list
                recordsToUpdate.add(victim);
            	recordsToDelete.add(master);
            }
        }
    }
    
    // Adds an error to a list of pairs
    private static void addError(List<Object_Merge_Pair__c> pairs, String reason) {
        for (Object_Merge_Pair__c p:pairs)
            addError(p, reason);
    }
    
    // Adds an error to a pair
    private static void addError(Object_Merge_Pair__c p, String reason) {
        p.Status__c = 'Error';
        p.Error_Reason__c = reason;
    }
    
    // Builds and returns query
    private static String getQuery(Object_Merge_Handler__c handler, Map<Id, List<Object_Merge_Field__c>> fields) {
        
        // Start query with parent fields
        String query = 'SELECT Id';
        query += queryFields(fields.get(handler.Id));
        
        // Add to query with child objects
        for (Object_Merge_Handler__c h:handler.Object_Merge_Handlers__r) {
            
            query += ', (SELECT Id, ' + h.Object_Lookup_Field_API_Name__c;
            query += queryFields(fields.get(h.Id));
            query += ' FROM ' + h.Child_Relationship_Name__c + ')';
        }
        
        // Finish query
        query += ' FROM ' + handler.Name + ' WHERE Id IN :parentIds';
        
        return query;
    }
    
    // Returns string of fields to use in query
    private static String queryFields(List<Object_Merge_Field__c> fields) {
        String ret = '';
        if (fields != null) {
            Set<String> fieldNames = new Set<String>{'createddate', 'lastmodifieddate'};
            for (Object_Merge_Field__c f:fields)
                if (!f.Name.toLowerCase().equals('id'))
                	fieldNames.add(f.Name.toLowerCase());
            for (String fn:fieldNames)
                ret += ', ' + fn;
        }
        return ret;
    }
    
    // Merges victim field into master field if master field is not null
    private static Boolean mergeFields(List<Object_Merge_Field__c> fields, SObject master, SObject victim) {
        Boolean ret = false;
        if (fields != null) {
            for (Object_Merge_Field__c f:fields) {
                if (master.get(f.Name) == null && victim.get(f.Name) != null) {
                    master.put(f.Name, victim.get(f.Name));
                    ret = true;
                }
            }
        }
        return ret;
    }
    
    // Return List of Lists of SObjects, grouped by type with parents at end
    private static List<List<SObject>> groupSObjects(List<SObject> objects, Object_Merge_Handler__c handler) {
        Schema.SObjectType parentType = Schema.getGlobalDescribe().get(handler.Name);
        List<SObject> parents = new List<SObject>();
        Map<Schema.SObjectType, List<SObject>> objectMap = new Map<Schema.SObjectType, List<SObject>>();
        for (SObject so:objects) {
            if (so.getSObjectType() == parentType) {
                parents.add(so);
            } else {
                if (!objectMap.containsKey(so.getSObjectType()))
                    objectMap.put(so.getSObjectType(), new List<SObject>());
                objectMap.get(so.getSObjectType()).add(so);
            }
        }
        List<List<SObject>> ret = objectMap.values();
        ret.add(parents);
        return ret;
    }
    
    public class ObjectMergePairException extends Exception {}
}