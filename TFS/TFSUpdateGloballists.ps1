PARAM($GlobalListName,$GlobalEntryValue,$TFSServer)

clear
#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

#sample parameters for script testing
if(!$GlobalListName){
	$GlobalListName="Builds - Baloise"
	$GlobalEntryValue="24.0.11.0"
	$TFSServer="http://tfs-be:9091/tfs/DefaultCollection/Baloise"

}

#display the input parameters
Write-Host "====================================================="
Write-Host "TFS server  :  $TFSServer"
Write-Host "Global List :  $GlobalListName"
Write-Host "New value   :  $GlobalEntryValue"
Write-Host "====================================================="

	$WIT = Connect2TFSWorkitems $TFSServer
    [xml]$export = $WIT.ExportGlobalLists()
	$globalLists = $export.ChildNodes[0]
	$globalList = $globalLists.SelectSingleNode("//GLOBALLIST[@name='$GlobalListName']")
	Write-host "Current Global List"
	$globalList.childNodes
     # if no GL then add it
	If ($globalList -eq $null)
    	{
			Write-Host "GLobalist with the name '$GlobalListName' was not found. Operation Aborted" 
			Write-host  "Available Global lists" 
			$globalLists.childNodes
	   		exit 1
    	}
	else
 		{
	    	#Create a new node.
		    $GlobalEntry = $export.CreateElement("LISTITEM");
		    $GlobalEntryAttribute = $export.CreateAttribute("value");
		    $GlobalEntryAttribute.Value = $GlobalEntryValue
		    $GlobalEntry.Attributes.Append($GlobalEntryAttribute);
		    #Add new entry to list
		    $globalList.AppendChild($GlobalEntry)
		    #Import list to server
			Write-host "`r`nUpdated Global list"
			$globalList.childNodes
		   $WIT.ImportGlobalLists($globalLists)
		}
	