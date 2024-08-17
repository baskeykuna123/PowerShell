PARAM($application,$Release,$ICORPTargetDate)

clear
#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop


if(!$Release){
	$assignedto="Wyckmans, Glenn"
	$application="NINA"
	$Release="R32"
	$ICORPTargetDate="05/03/2018 16:30:00"
	$TFSServer="http://svw-be-tfsp002:9192/tfs/DefaultCollection"
}

#Reading Global manifest to get latest Version
$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest  )

#Get the application no to be updated
$node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']")
$DeploymentVer=$node.GlobalReleaseVersion
$TFSServer="http://tfs-be:9091/tfs/DefaultCollection"
#$TFSServer="http://svw-be-tfsp002:9192/tfs/DefaultCollection"
$teamproject="Baloise"
$WorkitemType=""
$traversal=@("Requested")
$WIT = Connect2TFSWorkitems $TFSServer

ForEach($app in $application.split(',')){
	$title=[string]::Format("{0} {1} Deployment - {2}",$Release,$app,$DeploymentVer)
	$workItem=$WIT.Projects["$teamproject"].WorkItemTypes["Patch Request"].NewWorkItem()
	$workItem["Platform"]=$app
	
	#Patch Request Mandatory Fields
	$workItem.AreaPath  ="Baloise"
	$workItem.IterationPath="Baloise\$Release\ICT\P0000 - Deployment Use Only"
	$workItem["PatchType"]="PlannedIteration"
	$workItem.Title=$title
	$workItem.State="New"
	$assignedto="De Baere, Els <balgroupit\H001649>"
	Switch($app){
			"MDM" {$assignedto="De Baere, Els"}
		}
	
	$workItem["Assigned To"]=$assignedto
	$workItem["IcorpTargetDate"]=$ICORPTargetDate
	$workItem.Validate()
	$workItem.Save()
	$PatchRequest=$WIT.GetWorkItem($workItem.Id)
	
	Write-Host "================================$($app)==============================================="
	Write-Host "Release       :" $Release
	Write-Host "Assigned To   :" $assignedto
	Write-Host "Patch ID      :" $PatchRequest.Id
	Write-Host "================================$($app)============================================="

	#Preparing Patch to Requested State

	foreach($state in $traversal){
		$PatchRequest.State=$state
		$PatchRequest["Assigned To"]=$assignedto
		$workItem["IcorpTargetDate"]=$ICORPTargetDate
		$PatchRequest.Save()
		
	}
}