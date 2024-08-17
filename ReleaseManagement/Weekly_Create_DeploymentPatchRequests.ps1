PARAM($application,$Release,$ICORPTargetDate)

if(!$Release){
	$application="OMS"
	$Release="R36"
	$ICORPTargetDate="12/07/2021 16:30:00"
}

clear

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

Write-Host "===============Input Parameters====================================="
Write-Host "Application(s)    : $application"
Write-Host "Release           : $Release"
Write-Host "ICORP Target Date : $ICORPTargetDate"
Write-Host "===============Input Parameters====================================="

#Reading Global manifest to get latest Version
$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest  )
#Get the application no to be updated
$node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']")
$DeploymentVer=$node.GlobalReleaseVersion
$TFSServer="http://tfs-be:9091/tfs/DefaultCollection"
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
	$assignedto="Turumella, Uday <balgroupit\H036196>"
	Switch($app){
			"MF"   {$assignedto="Vanderheyden, Erik"}
			"OMS"  {$assignedto="Wesemael, Lieven"}
			"Cleva"{$assignedto="Van Langenhove, Ann"}
			"Talk" {$assignedto="Ceusters, Ivo"}
			"ESB" {$assignedto="Sah, Piyush"}
			"Babe" {$assignedto="Bhattacharya, Aditi"}
			"CDS" {$assignedto="Bhattacharya, Aditi"}
			"MwebInternal" {$assignedto="Bhattacharya, Aditi"}
			"MwebBroker" {$assignedto="Bhattacharya, Aditi"}
			"MNet" {$assignedto="De Roock, Kenneth <balgroupit\H034061>"}
			#"Babe" {$assignedto="Herman, Gaetano"}
			#"CDS" {$assignedto="Herman, Gaetano"}
			#"MwebInternal" {$assignedto="Herman, Gaetano"}
			#"MwebBroker" {$assignedto="Herman, Gaetano"}			
			"MDM" {$assignedto="De Baere, Els <balgroupit\H001649>"}
			"TaskCreateEngine" {$assignedto="ICT AT CCM, PROD"}
			"NINA" {$assignedto="Wyckmans, Glenn <balgroupit\H000840>"}
			"TOSCA"{$assignedto="Belloguet, Miguel"}
			"Fireco"{$assignedto="Coudeville, Olivier"}
			"DocumentTransformer"{$assignedto="Van de Vorst, Bart <balgroupit\H038492>"}
			"BDA" {$assignedto="De Roock, Kenneth <balgroupit\H034061>"}
			"SASLoader"{$assignedto="Van Langenhove, Ann"}
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