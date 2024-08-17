param($MailRecipients)
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

#Connecting to TFS
$pwd=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])

# Reports

$reports=""
$today=Get-Date -Format "MM/dd/yyyy"
#$report+="</TABLE>"
$report="<TABLE class='rounded-corner'>"
$report+="<TR align=center><TH colspan='4'>DEFECTS LISTS DATE - $today</TH></TR>"
$report+="<TR align=center><TH><B>Defect ID</B></TH><TH><B>Title</B></TH><TH><B>State</B></TH><TH><B>Assigned To</B></TH></TR>"

#Fetch Data 
$Version=@("Baskey, Kuna","Turumella, Uday","Pai, Shivaji","Kumar Jha, Pankaj","Gorichela, Deepak","Adhikary, Bireshwar")
foreach($name in $Names){
$WIQL = "select * from WorkItems where [Work Item Type] = 'Patch Request' and [State] <> 'Closed' and [Assigned To] = '$($name)'"

$WorkItems = $WIT.Query($WIQL)
#$WorkItems
$DefectId = $WorkItems.ID
$DefectId

foreach($ID in $DefectId){
$ID
$test = "select * from WorkItems where [Work Item Type] = 'Defect' and [Id] = '$ID' and [Assigned To] = '$($name)'"
$Defects = $WIT.Query($test)
$Title=$Defects.Title
$Title
$State=$Defects.State
$AssignedTo=$Defects.AssignedTo
$report+="<TR align=center><TH><B>$ID</B></TH><TH><B>$Title</B></TH><TH><B>$State</B></TH><TH><B>$name</B></TH></TR>"

}
}
$reports+=$report
$TemplatefilePath=join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\Defects.html"
$HtmlBody = [system.IO.File]::ReadAllLines($TemplatefilePath)
$HtmlBody = $HtmlBody -ireplace "#ReportINFO#",$reports
#$HtmlBody = $HtmlBody -ireplace "#ENV#",$ENV
#$HtmlBody | Out-File Filesystem::$temphtmlfile
$subject="Team Defects List  Date - $today"
#SendMail -To $MailRecipients -subject $subject -body $HtmlBody
SendMailWithoutAdmin -To $MailRecipients -body ([string]$HtmlBody) -subject $subject