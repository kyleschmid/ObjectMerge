({
	doInit : function(component, event, helper) {
		
        helper.getDuplicates(component, false, false, null);
	},
    
    handleRowAction : function(component, event, helper) {
        
        var action = event.getParam("action");
        var row = event.getParam("row");
        var records = component.get("v.data");
		
        switch (action.name) {
            
            case "make_master" : {
                
                var i = 0;
                
                while (i < records.length) {
                    
                    if (records[i].Id == row.Id) {
                        records[i].duplicateBehavior = "Master";
                    } else if (records[i].duplicateBehavior == "Master") {
                        records[i].duplicateBehavior = "Duplicate";
                    }
                    
                    i++;
                }
                
                break;
                
            } case "make_victim" : {
                
                var rowFound = false;
                var needsNewMaster = false;
                var newMasterIndex = -1;
                var i = 0;
                
                while (i < records.length && (rowFound == false || (rowFound == true && (needsNewMaster == false || newMasterIndex < 0)))) {
                    
                    if (records[i].Id == row.Id) {
                        
                        rowFound = true;
                        
                        if (records[i].duplicateBehavior == "Master") {
                            needsNewMaster = true;
                        }
                        
                        records[i].duplicateBehavior = "Duplicate";
                        
                    } else if (records[i].duplicateBehavior == "Duplicate") {
                        
                        newMasterIndex = i;
                    }
                    
                    i++;
                }
                
                if (newMasterIndex >= 0) {
                    records[newMasterIndex].duplicateBehavior = "Master";
                }
                
                break;
                
            } case "do_not_merge" : {
                
                var i = 0;
                while (i < records.length) {
                    
                    if (records[i].Id == row.Id) {
                        records[i].duplicateBehavior = "Do Not Merge";
                        break;
                    }
                    
                    i++;
                }
                
                break;
            }
        }
        
        component.set("v.data", records);
    },
    
    mergeDuplicates : function(component, event, helper) {
        
        var records = component.get("v.data");
        
        var masterId;
        var victimIds = [];
        
        var i = 0;
        while (i < records.length) {
            
            if (records[i].duplicateBehavior == "Master") {
                masterId = records[i].Id;
            } else if (records[i].duplicateBehavior == "Duplicate") {
                victimIds.push(records[i].Id);
            }
            
            i++;
        }
        
        if (!masterId || victimIds.length == 0) {
            helper.displayToast(component, "error", "Error", "At least one master and one duplicate record must be selected to merge.");
        } else {
            helper.mergeRecords(component, masterId, victimIds, 0);
        }
    }
})