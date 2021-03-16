# Object Merge

Open-source solution for merging Salesforce objects and their related objects.

## Description

This solution allows you to specify merging rules for parent objects, their fields, their related objects, and their related objects fields.

## Installation

ObjectMerge is released under the open source BSD license. Contributions (code and otherwise) are welcome and encouraged. You can install in one of two ways:

### Unmangaged Package

You can go to one of the following links to install Object Merge as an unmanaged package:
* <a href="	https://login.salesforce.com/packaging/installPackage.apexp?p0=04t0H000000YOey" target="_blank" >Production</a>
* <a href="	https://test.salesforce.com/packaging/installPackage.apexp?p0=04t0H000000YOey" target="_blank" >Sandbox</a>

### Ant/Force.com Migration Tool
You can fork this repository and deploy the unmanaged version of the code into a Salesforce org of your choice.

* Fork the repository by clicking on the "Fork" button in the upper-righthand corner. This creates your own copy of Object Merge for your Github user.
* Clone your fork to your local machine via the command line
```sh
$ git clone https://github.com/YOUR-USERNAME/ObjectMerge.git
```
* You now have a local copy on your machine. Object Merge has some built-in scripts to make deploying to your Salesforce org easier. Utilizing ant and the Force.com Migration tool, you can push your local copy of Object Merge to the org of your choice. You'll need to provide a build.properties to tell ant where to deploy. An example file might look like:

```
sf.username = YOUR_ORG_USERNAME
sf.password = YOUR_ORG_PASSWORD
sf.serverurl = https://login.salesforce.com ##or test.salesforce.com for sandbox environments
sf.maxPoll = 20
```

* Now deploy to your org utilizing ant

```sh
$ cd ObjectMerge
$ ant deploy
```

* You'll need to give the System Administrator profile access to the following:
  * Fields on the newly-created Object Merge Handler, Object Merge Handler Field, and Object Merge Pair objects
  * The Object Merge Handlers and Object Merge Pairs tabs
  * The Child Handler and Parent Handler record types on Object Merge Handler
* You'll also need to assign the Parent Object Merge Handler Layout to the Parent Handler record type for all profiles on the Object Merge Handler object

## Uninstallation

### Unmangaged Package

Go to Setup>Installed Packages and click "Uninstall" next to ObjectMerge.

### Ant/Force.com Migration Tool

* Undeploy using ant

```sh
$ cd ObjectMerge
$ ant undeploy
```

* Erase the Object Merge Handler, Object Merge Field, and Object Merge Pair objects under Setup>Create>Custom Objects>Deleted Objects

## Using ObjectMerge

Once installed, you'll want to set up your first Object Merge Handler. To do so, follow these instructions:

1. Go to the Object Merge Handlers table
2. Create a new Object Merge Handler with the Parent Handler record type
	* Populate the Object API Name with the API name of the main object to be merged (e.g. "Account")
3. Click "New" on the Object Merge Fields related list
  	* Populate each Object Merge Field record with the API name of the field on the parent object (e.g. "Name" or "Description")
  	* When the merge is performed, any field that is null on the master but not null on the victim will be copied over to the master
  	* Ignore the "Use for Matching" checkbox for parent fields
4. Go back to the Object Merge Handler and click "New" on the Object Merge Handlers related list
  	* Select "Child Handler" for the Record Type
  	* Populate the Object API Name of the field with the API name of the object related to the parent object that you want to merge (e.g. "Contact")
  	* Populate the Object Lookup Field API Name with the API name of the field that looks-up to the parent object (e.g. "AccountId")
    * Populate the Order of Execution field with the order in which you want this object to be processed relative to other child objects. This is not required.
  	* Populate the Standard Action field with what you want to happen to the related object record when a duplicate is not found on the master:
    	* Move Victim: Victim record will be re-parented to master
    	* Clone Victim: Victim record will be cloned and the clone will be parented to master (helpful for Master-Detail relationships that don't allow reparenting)
    	* Delete Victim: Deletes the victim record entirely
  	* Populate the Merge Action field with what you want to have happen when a duplicate related record is found:
    	* Keep Oldest Created: The newest created will be merged into the oldest created. The oldest created will be reparented if it is the victim. The newest created will then be deleted.
    	* Keep Newest Created: The oldest created will be merged into the newest created. The newest created will be reparented if it is the victim. The oldest created will then be deleted.
    	* Keep Last Modified: The oldest last modified will be merged into the newest last modified. The newest last modified will be reparented if it is the victim. The oldest last modified will then be deleted.
    	* Delete Duplicate: The victim will be deleted without any merging.
    	* Keep Master: The victim will be merged into the master and the victim will be deleted
    * Check the "Clone Reparented Victim" checkbox if you'd like the victim to be cloned if it is the winner. This is useful for master-detail relationships that don't allow reparenting. In this case, the victim will be cloned and the master will be merged into the clone. The clone will then be reparented and inserted. Both the master and the victim will be deleted.
5. Click "New" on the Object Merge Fields related list
  	* Create a new object Merge Field record for every field you want to merge for this object
  	* Check the "Use for Matching" checkbox for any fields that you want to consider when finding duplicates
6. You're now ready to perform your first merge! Go to the Object Merge Pairs tab and click "New"
  	* Populate the Master ID with the ID of the record you want to keep
  	* Populate the Victim ID with the ID of the record you want to delete
  	* Ignore the Status field
  	* Click Save
7. If the merge was successful, the Status field will be populated with "Merged". If not, it will be populated with "Error" and the Error Reason field will give some detail around why the merge failed. You can change the status to "Retry" to try the merge again.

## Typical Use Cases

### Data Loader

While this tool doesn't identify duplicates, Salesforce has great standard features for doing so. You can run a report to get duplicate IDs and then use Data Loader with the Object Merge Pair object to merge duplicates en masse:
* Sort by Duplicate Record Set Name then in a manner to make your master records show up first
* Add columns for Master ID and Victim ID
* Copy the first ID to the Master ID field
* Use the Excel formulas in Example_Duplicate_Report.xlsx for the rest of the Master ID and Victim ID rows
* Copy/paste the Master ID and Victim ID columns into a new spreadsheet
* Sort by Victim ID and remove all rows with blank Victim IDs
* Save as a .csv
* Use Data Loader to insert these pairs into the Object Merge Pair object

### ObjectMerge Duplicate Manager

The ObjectMerge Duplicate Manager is a Lightning Component that allows users to merge records straight from the record detail page. When included on a Lightning Record Page, the component will find Duplicate Record Items that are part of any Duplicate Record Set that includes the current record (these get generated by the "Report" option with Salesforce Duplicate Rules). If duplicates are found, users can merge two or more records using the component. You can control which fields display in the component's table by including a comma-seperated list of field API names in the "Fields" attribute of the component within the Lightning Record Page editor.

### DemandTools

If you have a license to DemandTools MassImpact, use this <a href="https://github.com/kyleschmid/ObjectMerge/blob/master/DemandTools_MassImpact_Set_Status_to_Retry.MIxml" target="_blank" >scenario</a> to set the statuses of all Object Merge Pair records with an "Error" status to "Retry" to attempt the merges again.
