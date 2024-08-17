
$maxEffort=250
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

#Connecting to TFS
[string] $tfsServer = "http://tfs-be:9091/tfs/DefaultCollection"
$today=Get-Date -Format "MM/dd/yyyy"
$pwd=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
$str="select * from WorkItems where [Work Item type] = 'Task' and [System.CreatedDate] > '01/01/2019'"
$Workitmes=$WIT.Query($str)
$Workitmes.Count
$ResoureInfo=""
foreach($Workitem in $Workitmes){
		$ExtraEfforts=$false
		$Revinfo=""
		
	foreach($Rev in $Workitem.Revisions){
		if($Rev.Fields["Completed Work"].Value -gt $maxEffort){
			$changeDate=[datetime]$Rev.Fields["System.ChangedDate"].Value
			$originalEffort=$Rev.Fields["Completed Work"].OriginalValue
			$updateEffort=$Rev.Fields["Completed Work"].Value
			$ExtraEfforts=$true
			$Revinfo+="<TR><TD>$changeDate</TD><TD>$originalEffort</TD><TD>$updateEffort</TD></TR>"
		}
	}
	if($ExtraEfforts){
		$TaskNumber=$Workitem.Id
		$assignedTo=$Workitem.Fields["Assigned To"].Value 
		$ResoureInfo+="<TABLE class='rounded-corner'>"
		$ResoureInfo+="<TR align=center><TH colspan='2'>$assignedTo</TH><TH>Task Nr : $TaskNumber</TH></TR>"
		$ResoureInfo+="<TR align=center><TH>Change Date</TH><TH>Original Effort</TH><TH>Updated Effort</TH></TR>"
		$ResoureInfo+=$Revinfo
		$ResoureInfo+="</TABLE>"
	}
	}

$HTMLTemplate=[String]::Format("{0}Notifications\Templates\ExtraEfforts.html",$Global:ScriptSourcePath)
$HtmlBody=[system.IO.File]::ReadAllLines($HTMLTemplate)
$HtmlBody = $HtmlBody -replace "#EFFORT#",$maxEffort
$HtmlBody = $HtmlBody -replace "#Resource INfo#",$ResoureInfo

SendMailWithoutAdmin -To "Shivaji.pai@baloise.be" -subject "Baloise Tasks - Over Booking Tasks" -body $HtmlBody



