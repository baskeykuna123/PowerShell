#############################################################
#
# Description: Automatically creates a defect in TFS.
# Author:      Shivaji S Pai
# 
#############################################################
 

PARAM($assignedto,$application,$Release,$Environment,$ICORPTargetDate)


#loading Function
#if(Get-Module -name LoadFunctions){
#	Remove-Module LoadFunctions
#}
#$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
#Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

."\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Functions\fnSetGlobalParameters.ps1"

# Clear Output Pane
clear

if(!$Release){
	$assignedto='Pai, Shivaji'
	$application="ESB"
	$Release="R26"
	$Environment="ICORP"
	$ICORPTargetDate="05/03/2018 16:30:00"
}

# get an instance of TfsTeamProjectCollection
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.WorkItemTracking.Client") 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")  
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.VersionControl.Client")  



#Reading Global manifest to get latest Version
$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest  )
#Get the application no to be updated
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']")
$DeploymentVer=$node.GlobalReleaseVersion

$teamproject="Baloise"
$WorkitemType="Patch Request"
$title=[string]::Format("{0} {1} Deployment - {2}",$Release,$application,$DeploymentVer)
$traversal=@("Requested","Approved","Merged","ICORP Requested")

#connecting to TFS 
[string] $tfsServer = "http://tfs-be:9091/tfs/DefaultCollection"
$userid="prod\builduser"
$pwd="Wetzel01" | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($userid,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$WIT = [Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore] $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
$workItem=$WIT.Projects["$teamproject"].WorkItemTypes["$WorkitemType"].NewWorkItem()


#Patch Request Mandatory Fields
$workItem["Platform"]=$application
$workItem.AreaPath  ="Baloise"
$workItem.IterationPath="Baloise\$Release\P000K - Deployment- Validation Tests"
$workItem["PatchType"]="PlannedIteration"
$workItem.Title=$title
$workItem.State="New"
$workItem["Assigned To"]=$assignedto
$workItem["IcorpTargetDate"]=$ICORPTargetDate
$workItem.Validate()
$workItem.Save()
$PatchRequest=$WIT.GetWorkItem($workItem.Id)

#Preparing Patch to Requested State

foreach($state in $traversal){
	$PatchRequest.State=$state
	$PatchRequest["Assigned To"]=$assignedto
	$workItem["IcorpTargetDate"]=$ICORPTargetDate
	$PatchRequest.Save()
	
}
Write-Host "================================$($application)==============================================="
Write-Host "Release       :" $Release
Write-Host "Assigned To   :" $assignedto
Write-Host "Patch Request :" $PatchRequest.Id
Write-Host "================================$($application)============================================="