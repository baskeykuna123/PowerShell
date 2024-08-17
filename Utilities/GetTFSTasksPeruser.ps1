PARAM($AssignedTo,$Emailaddress)
clear

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

if(!$Emailaddress){
$Emailaddress='Shivaji.pai@baloise.be'
$AssignedTo="pai, Shivaji"
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

$today = get-date -Format "MM/dd/yyyy"
$StartDate=$today.AddDays(-($today).DayOfWeek.value__) 
$StartDate=$StartDate.Date
$EndDate=$today.AddDays(7-($today).DayOfWeek.value__) 
$EndDate=$EndDate.Date

Write-host "Week Start Date :" $StartDate
Write-host "Week End Date :" $EndDate
#Connecting to TFS
[string] $tfsServer = "http://tfs-be:9091/tfs/DefaultCollection"
$pwd=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
#$str="select * from WorkItems where [Work Item type] = 'Task' and  [system.AssignedTO]='$($AssignedTo)' and [System.ChangedDate] > '$($StartDate)' "#and  [System.ChangedDate] < '$($EndDate)' "
$str="select * from WorkItems where [Work Item type] = 'Task' and  [system.AssignedTO]='$($AssignedTo)'"
$Workitmes=$WIT.Query($str)
$Workitmes.Count
$ResoureInfo=""
[datetime]$currentdate = $startDate
$WeeklyEfforts=0
while($currentdate -le $EndDate){
$Revinfo="<TABLE class='rounded-corner'>"
$Revinfo+="<TR align=center><TH>Task ID</TH><TH>Task Title</TH><TH>Change Date</TH><TH>Original Effort</TH><TH>Updated Effort</TH><TH>Acutal Effort</TH></TR>"
$totalEffort=0
foreach($Workitem in $Workitmes){
		
		$TaskNumber=$Workitem.Id
		$title=$Workitem.Title
		#Write-Host "Checking all Revisions"
		Foreach($Rev in $Workitem.Revisions){
		$changeDate=$Rev.Fields["System.ChangedDate"].Value
		if($changeDate.Date -eq $currentdate.Date){
		#if(($changeDate -gt $StartDate) -and ($changeDate -lt $EndDate)){
			$originalEffort=$Rev.Fields["Completed Work"].OriginalValue
			$updateEffort=$Rev.Fields["Completed Work"].Value
			$acutaleffort=$updateEffort-$originalEffort
			if($Rev.Fields["Completed Work"].IsChangedInRevision){
				$totalEffort+=$acutaleffort
				$Revinfo+="<TR><TD>$TaskNumber</TD><TD>$title</TD><TD>$changeDate</TD><TD>$originalEffort</TD><TD>$updateEffort</TD><TD>$acutaleffort</TD></TR>"
				
			}
		}
	
	
}
}
$DisplayDate=[string]::Format("{0}-{1}-{2}",$currentdate.Day,$currentdate.Month,$currentdate.Year)
$Revinfo+="<TR><TH colspan='5' align='center'> $DisplayDate ($($currentdate.DayOfWeek)) - Efforts</TH><TH>$totalEffort</TH></TR>"
$Revinfo+="</TABLE>"
$ResoureInfo+=$Revinfo
$WeeklyEfforts+=$totalEffort
$currentdate=$currentdate.AddDays(1)
}
$ResoureInfo+="<TABLE class='rounded-corner'>"
$ResoureInfo+="<TR><TH colspan='5' align='center'>Current Week Efforts</TH><TH>$WeeklyEfforts</TH></TR>"
$ResoureInfo+="</TABLE>"

$HTMLTemplate=[String]::Format("{0}Notifications\Templates\Efforts.html",$Global:ScriptSourcePath)
$HtmlBody=[system.IO.File]::ReadAllLines($HTMLTemplate)
$HtmlBody = $HtmlBody -replace "#Resource INfo#",$ResoureInfo

SendMailWithoutAdmin -To $Emailaddress -subject "$AssignedTo - Current Week Efforts" -body $HtmlBody



