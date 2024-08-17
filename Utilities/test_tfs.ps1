#$ErrorActionPreference = "Stop"
param($Application,$Environment)
clear

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$UpdateVersionScriptfile="$ScriptDirectory\ReleaseManagement\UpdateReleaseVersion.ps1"

#adding TFS Asseblies
Add-Type -AssemblyName System.web
if ((Get-PSSnapIn -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
    Add-PSSnapin Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue
}

# get an instance of TfsTeamProjectCollection
#[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.WorkItemTracking.Client") 
#[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")  
#[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.VersionControl.Client")  


#updates the properties files


[string] $tfsServer = "http://svw-be-tfsp002:9192/tfs/DefaultCollection/"

#$Resources=@()
$today=Get-Date -Format "MM/dd/yyyy"
#Connecting to TFS

$pwd=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
$AllResources=""
$str="select * from WorkItems where [Work Item type] = 'PATCH REQUEST' and [State] = '$($Environment) Planned' and [Platform] = '$($Application)' and [PatchType] ='PlannedIteration'"
$Workitmes=$WIT.Query($str)
$Patch_ID=$Workitmes.ID
$Initial_State=$Workitmes.State
write-host "------------------------------------------------------------------------------"
write-host "Patch ID:::"        $Patch_ID
write-host "State:::"           $Initial_State
write-host "Application Name":: $Application
write-host "-------------------------------------------------------------------------------"
$state="$($Environment) Deployed"
$PatchRequest=$WIT.GetWorkItem($Patch_ID)
$PatchRequest["State"]=$state
$PatchRequest.Save()