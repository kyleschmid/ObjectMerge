/*
    BSD 3-Clause License
    
    Copyright (c) 2021, Kyle Schmid, Huron Consulting Group
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
public class ObjectMergeHandleUsers implements Queueable {
	
    private Set<Id> pairIds; // Set of Object Merge Pair IDs to merge after user deactivation
    private Set<Id> userIdsToDeactivate; // Set of User IDs to deactivate
    private Map<Id, Id> ownerIdMap; // Map of deactivated User IDs to User IDs associated with master Contact
	
    // Method to handle user deactivation when Victim ID is Contact with active user
    public static void handleUsers(List<Object_Merge_Pair__c> pairs) {
        
        Set<Id> pairIds = new Set<Id>(); // Set of Object Merge Pair IDs to process
        Map<Id, Id> contactIdMap = new Map<Id, Id>(); // Map of Victim Contact ID to Master Contact ID
        
        // Loop over Object Merge Pairs and identify subset with Processing status
        for (Object_Merge_Pair__c p:pairs) {
            
            if (p.Status__c == 'Processing') {
                pairIds.add(p.Id);
                contactIdMap.put(Id.valueOf(p.Victim_ID__c), Id.valueOf(p.Master_ID__c));
            }
        }
        
        // Check to see if we have any pairs to process
        if (!pairIds.isEmpty()) {
            
            Set<Id> userIdsToDeactivate = new Set<Id>(); // Set of User IDs to deactivate
            Map<Id, Id> contactUserIdMap = new Map<Id, Id>(); // Map of Contact ID to User ID
            
            // Query users and populate set/map
            for (User u:[SELECT Id, ContactId FROM User WHERE (IsPortalEnabled = true AND ContactId IN :contactIdMap.keySet()) OR (IsActive = true AND ContactId IN :contactIdMap.values())]) {
                
                contactUserIdMap.put(u.ContactId, u.Id); // Put User ID in Contact ID to User ID map
                
                // Add User ID to set if it's in the contactIdMap keySet
                if (contactIdMap.containsKey(u.ContactId))
                    userIdsToDeactivate.add(u.Id);
            }
            
            // Check to see if we have any users to deactivate
            if (!userIdsToDeactivate.isEmpty()) {
                
                Map<Id, Id> ownerIdMap = new Map<Id, Id>(); // Map of deactivated User IDs to User IDs associated with master Contact
                
                // Loop over Contact ID map
                for (Id victimContactId:contactIdMap.keySet()) {
                    
                    Id oldUserId = contactUserIdMap.get(victimContactId); // Grab User ID associated with victim Contact
                    Id newUserId = contactUserIdMap.get(contactIdMap.get(victimContactId)); // Grab User ID associated with master Contact
                    
                    // Add User IDs to map if both are non-null
                    if (oldUserId != null && newUserId != null)
                        ownerIdMap.put(oldUserId, newUserId);
                }
                
                deactivateUsersFuture(userIdsToDeactivate); // Call @future method to deactivate users and avoid mixed DML error
                
                // Enqueue job to process merge when users are fully deactivated
                System.enqueueJob(new ObjectMergeHandleUsers(pairIds, userIdsToDeactivate, ownerIdMap));
            }
        }
    }
    
    // Method to deactivate users asyncronously
    @future
    private static void deactivateUsersFuture(Set<Id> userIdsToDeactivate) {
        
        deactivateUsers(userIdsToDeactivate); // Call synchronous method from future context
    }
    
    // Method to deactivate users syncronously
    @testVisible
    private static void deactivateUsers(Set<Id> userIdsToDeactivate) {
        
        // Query users
        List<User> users = [SELECT Id, ContactId FROM User WHERE Id IN :userIdsToDeactivate];
        
        // Loop over users and set fields
        for (User u:users) {
            
            u.Email = UserInfo.getOrganizationId() + '.' + u.Id + '@merged.invalid'; // Set to something unique to org/record
            u.Username = u.Email;
            u.CommunityNickname = u.Id;
            u.IsActive = false;
            u.IsPortalEnabled = false;
            u.FederationIdentifier = null;
        }
        
        update users; // Update users
    }
    
    // Constructor for queueable implementation
    public ObjectMergeHandleUsers(Set<Id> pairIds, Set<Id> userIdsToDeactivate, Map<Id, Id> ownerIdMap) {
		
        // Set class instance variables
        this.pairIds = pairIds;
		this.userIdsToDeactivate = userIdsToDeactivate;
        this.ownerIdMap = ownerIdMap;
    }
	
    // Execute method for queueable implementation
	public void execute(QueueableContext context) {
        
        execute(!Test.isRunningTest()); // Only enequeue another job if we aren't in test context
    }
    
    // Execute method with seperate logic for test classes
	public void execute(Boolean enqueueAnotherJob) {
        
        // Check to see if all users are fully deactivated and process merges if so
        if ([SELECT Id FROM User WHERE IsPortalEnabled = true AND Id IN :this.userIdsToDeactivate LIMIT 1].isEmpty()) {
            
            // Query for Object Merge Pairs
            List<Object_Merge_Pair__c> pairs = [SELECT Id, Master_ID__c, Victim_ID__c, Status__c FROM Object_Merge_Pair__c WHERE Id IN :this.pairIds];
            
            // Loop over Object Merge Pairs and set Status to Retry
            for (Object_Merge_Pair__c p:pairs)
                p.Status__c = 'Retry';
            
            ObjectMergeUtility.mergeRecordsWithOwners(pairs, this.ownerIdMap); // Merge records
            
            // Disable trigger, update Object Merge Pairs to log merge results, and re-enable triggers
            ObjectMergePairTriggerHandler.disable();
            update pairs;
            ObjectMergePairTriggerHandler.enable();
            
        } else if (enqueueAnotherJob) {
            
            // Enqueue another job if all users aren't fully deactivated yet
            System.enqueueJob(new ObjectMergeHandleUsers(this.pairIds, this.userIdsToDeactivate, this.ownerIdMap));
        }
    }
}