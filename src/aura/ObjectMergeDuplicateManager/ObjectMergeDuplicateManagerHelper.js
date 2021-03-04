({
    getDuplicates : function(component, isAfterMerge, isSuccess, mergePair) {
		
        component.set("v.showSpinner", true);
        
        var recordId = component.get("v.recordId");
        var fieldString = component.get("v.fields");
        var getDuplicatesAction = component.get("c.getDuplicates");
        
        getDuplicatesAction.setParams({
            "recordId" : recordId,
            "fieldString" : fieldString
        });
        
        getDuplicatesAction.setCallback(this, function(response) {
            
            if (response.getState() === "SUCCESS") {
                
                var result = response.getReturnValue();
                
                let nameColumn = {
                    label : "Name",
                    fieldName : "recordUrl",
                    type : "url",
                    typeAttributes : {label : {fieldName : "Name"}}
                };
                
                let behaviorColumn = {
                    label : "Behavior",
                    fieldName : "duplicateBehavior",
                    type : "text"
                };
                
                let actionColumn = {
                    type : "action",
                    typeAttributes : {
                        rowActions : [
                            {label : "Make Master", name : "make_master"},
                            {label : "Make Duplicate", name : "make_victim"},
                            {label : "Do Not Merge", name : "do_not_merge"}
                        ]
                    } 
                };
                
                let columns = [nameColumn];
                var fieldWrappers = result.fields;
                
                fieldWrappers.forEach(field => columns.push({ 
                    type : "text",
                    label : field.label,
                    fieldName : field.fieldName
                }));
                
                columns.push(behaviorColumn);
                columns.push(actionColumn);
                
                var records = result.records;
                
                var i = 0;
                while (i < records.length) {
                    
                    records[i].recordUrl = "/" + records[i].Id;
                    records[i].duplicateBehavior = i == 0 ? "Master" : "Duplicate";
                    i++;
                }
                
                component.set("v.columns", columns);
                component.set("v.data", records);
            }
            
            if (isAfterMerge) {
                
                if (isSuccess) {
            		this.displayToast(component, "success", "Success!", "Duplicate records have been merged.");
                } else {
                    this.displayToast(component, "error", "Error", mergePair.Error_Reason__c);
                }
                
            } else {
                
                component.set("v.showSpinner", false);
            }
        });
        
        $A.enqueueAction(getDuplicatesAction);
	},
    
	mergeRecords : function(component, masterId, victimIds, index) {
		
        component.set("v.showSpinner", true);
        
        var mergeRecordsAction = component.get("c.mergeRecords");
        
        mergeRecordsAction.setParams({
            "masterId" : masterId,
            "victimId" : victimIds[index]
        });
        
        mergeRecordsAction.setCallback(this, function(response) {
            
            if (response.getState() === "SUCCESS") {
                
                var mergePair = response.getReturnValue();
                this.handleMergePair(component, mergePair, masterId, victimIds, index);
                
            } else {
                
                this.unhandledException(component);
            }
        });
        
        $A.enqueueAction(mergeRecordsAction);
	},
    
    handleMergePair : function(component, mergePair, masterId, victimIds, index) {
        
        if (mergePair.Status__c == "Merged") {
            
            if (index >= victimIds.length - 1) {
                
                var recordId = component.get("v.recordId");
                
                if (masterId == recordId) {
                    this.getDuplicates(component, true, true, null);
                } else {
                    window.location.replace('/' + masterId);
                }
                
            } else {
                
            	this.mergeRecords(component, masterId, victimIds, index + 1);
            }
            
        } else if (mergePair.Status__c == "Error") {
            
            if (index == 0) {
                this.displayToast(component, "error", "Error", mergePair.Error_Reason__c);
            } else {
                this.getDuplicates(component, true, false, mergePair);
            }
            
        } else if (mergePair.Status__c == "Processing") {
            
            var getObjectMergePairAction = component.get("c.getObjectMergePair");
        	
            getObjectMergePairAction.setParams({
                "pairId" : mergePair.Id
            });
            
            getObjectMergePairAction.setCallback(this, function(response) {
                
                if (response.getState() === "SUCCESS") {
                    this.handleMergePair(component, response.getReturnValue(), masterId, victimIds, index);
                } else {
                    this.unhandledException(component);
                }
            });
            
            $A.enqueueAction(getObjectMergePairAction);
            
        } else {
            
            this.unhandledException(component);
        }
    },
    
    unhandledException : function(component) {
        
        this.displayToast(component, "error", "Error", "An unhandled exception occurred. Please contact your administrator if the problem persists.");
    },
    
    displayToast : function(component, type, title, message) {
        
        component.set("v.showSpinner", false);
        
        var toastEvent = $A.get("e.force:showToast");
        
        toastEvent.setParams({
            type : type,
            title : title,
            message : message
        });
        
        toastEvent.fire();
    }
})