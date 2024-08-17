param($Recipients,$Resources)
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


[string] $tfsServer = "http://tfs-be:9091/tfs/DefaultCollection"

#$Resources=@()
$today=Get-Date -Format "MM/dd/yyyy"
#Connecting to TFS

$pwd=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
$AllResources=""
foreach($Resource in $Resources.split(".")){
$Totalresourceefforts=0
$ResoureInfo="<TABLE class='rounded-corner'>"
$ResoureInfo+="<TR align=center><TH colspan='2'>$Resource</TH><TH colspan='1'>$today</TH></TR>"
$str="select * from WorkItems where [Work Item type] = 'Task' and State <> 'Closed' and [System.AssignedTo]='$Resource'"
$Workitmes=$WIT.Query($str)
foreach($Workitem in $Workitmes){
If($WorkItem.ChangedDate -ilike "$($today)*"){
	$currentIndex=($Workitem.Revisions[-1]).Index
	$Workitem.Id
	$Workitem.Title
	$old=$WorkItem.Revisions[$currentIndex].Fields["Microsoft.VSTS.Scheduling.CompletedWork"].OriginalValue
    $new=$WorkItem.Revisions[$currentIndex].Fields["Microsoft.VSTS.Scheduling.CompletedWork"].Value
	$todayseffort=$new-$old
	$Totalresourceefforts+=$todayseffort
	
	$ResoureInfo+="<TR><TD>$($Workitem.Id)</TD><TD>$($Workitem.Title)</TD><TD>$($todayseffort)</TD></TR>"
	}
}
$bgColor="green"
if($Totalresourceefforts -lt  7){
	$bgColor="Red"
}
$ResoureInfo+="<TR align=center><TH colspan='2'>Total</TH><TH colspan='1' style='background-color:$($bgColor)'>$Totalresourceefforts</TH></TR>"
$ResoureInfo+="</TABLE>"
$AllResources+=$ResoureInfo
}
$HTMLTemplate=[String]::Format("{0}Notifications\Templates\DailyEfforts.html",$Global:ScriptSourcePath)
$HtmlBody=[system.IO.File]::ReadAllLines($HTMLTemplate)
$HtmlBody = $HtmlBody -replace "#Resource INfo#",$AllResources

SendMailWithoutAdmin -To $Recipients -subject "Daily Task Efforts - Hexaware" -body $HtmlBody
