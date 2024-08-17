param([String]$Application,[String]$Environment)
clear

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

#adding TFS Asseblies
Add-Type -AssemblyName System.web
if ((Get-PSSnapIn -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
    Add-PSSnapin Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue
}
 
[string] $tfsServer = "http://tfs-be:9091/tfs/DefaultCollection"

#$Resources=@()
$today=Get-Date -Format "MM/dd/yyyy"
#Connecting to TFS

$pwd=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)

$WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
$status=@("$($Environment) Requested","$($Environment) Planned")
foreach($stat in $status) {
$stat
$str="select * from WorkItems where ([Work Item type] = 'PATCH REQUEST' and  [Platform] = '$($Application)' and [PatchType] ='PlannedIteration' and [State] = '$($stat)')"

$Workitmes=$WIT.Query($str)
$Patch_ID=$Workitmes.ID
$Initial_State=$Workitmes.State

if($Initial_State -ieq "$($Environment) Requested") {
write-host "------------------------------------------------------------------------------"
write-host "Patch ID:::"        $Patch_ID
write-host "State:::"           $Initial_State
write-host "Application Name":: $Application
write-host "-------------------------------------------------------------------------------"
        $state="$($Environment) Planned"
       
        $PatchRequest=$WIT.GetWorkItem($Patch_ID)
        $PatchRequest["State"]=$state
        $PatchRequest.Save()
        $status="$($Environment) Deployed"
        $PatchRequest=$WIT.GetWorkItem($Patch_ID)
        $PatchRequest["State"]=$status
        $PatchRequest.Save()
}

if($Initial_State -ieq "$($Environment) Planned") {
write-host "------------------------------------------------------------------------------"
write-host "Patch ID:::"        $Patch_ID
write-host "State:::"           $Initial_State
write-host "Application Name":: $Application
write-host "-------------------------------------------------------------------------------"
        $state="$($Environment) Deployed"
        $PatchRequest=$WIT.GetWorkItem($Patch_ID)
        $PatchRequest["State"]=$state
        $PatchRequest.Save()
        }
        }