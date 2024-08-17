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
$Names=@("Baskey, Kuna","Turumella, Uday","Pai, Shivaji","Kumar Jha, Pankaj","Gorichela, Deepak","Tiwari, Neha <Balgroupit\H038635>","ICT Change Services, PROD","Rahate, Snehit <Balgroupit\H038897>")
foreach($name in $Names){
$WIQL = "select * from WorkItems where [Work Item Type] = 'Defect' and [State] <> 'Closed' and [Assigned To] = '$($Names)'"

$WorkItems = $WIT.Query($WIQL)
#$WorkItems
$DefectId = $WorkItems.ID
$DefectId

foreach($ID in $DefectId){
$ID
$test = "select * from WorkItems where [Work Item Type] = 'Defect' and [Id] = '$ID' and [Assigned To] = '$($Names)'"
$Defects = $WIT.Query($test)
$Title=$Defects.Title
$Title
$State=$Defects.State
$AssignedTo=$Defects.AssignedTo
$report+="<TR align=center><TH><B>$ID</B></TH><TH><B>$Title</B></TH><TH><B>$State</B></TH><TH><B>$name</B></TH></TR>"

}
}
$Names=@("Baskey, Kuna","Turumella, Uday","Pai, Shivaji","Kumar Jha, Pankaj","Gorichela, Deepak","Tiwari, Neha <Balgroupit\H038635>","ICT Change Services, PROD","Rahate, Snehit <Balgroupit\H038897>")
foreach($name in $Names)
{
$WIQL = "select * from WorkItems where [Work Item Type] = 'Defect' and [State] <> 'Closed' and [Assigned To] = '$($name)'"
if ($name -ne $Names)
{
#Write-Output "No Open Defects" 
$report+= <TR> align=center "No Open Defects" </TR>
}
else
{
Write-output "<TR align=center><TH><B>$ID</B></TH><TH><B>$Title</B></TH><TH><B>$State</B></TH><TH><B>$name</B></TH></TR>"
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