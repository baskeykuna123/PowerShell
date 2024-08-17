PARAM
	(
	[string]$BuildNumber,
	[string]$Workspace,
	[string]$Environment
	)
	
if(!$BuildNumber){
	$BuildNumber="Staging_NINADB_20180214.1"
	$Workspace="e:\BuildTeam\Jenkins\workspace\$BuildNumber"
	$Environment="ICORP"
    
}

$ErrorActionPreference='Stop'

#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$temphtmlfile = [string]::Format("{0}\{1}_NINADB_{2}_.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"))
$TemplateFile=join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\NINA_DBDeployment.html"
$HtmlBody=get-content $TemplateFile

$Workspace=join-path $Workspace -ChildPath $BuildNumber
$packagesFolder=[string]::Format("{0}\Nina\{1}_{2}\{3}\Baloise.Nina.Database\",$global:NewPackageRoot,$BuildNumber.split('_')[0],$BuildNumber.split('_')[1],$BuildNumber.split('_')[2])
copy-item "$($packagesFolder)"  -Destination "$Workspace\" -Force -Recurse
$scriptfile=(Get-ChildItem $Workspace -Recurse -Filter "*$($Environment).bat").FullName
Set-Location (split-path $scriptfile)

if(test-path ($scriptfile)){
	Write-Host "==================================================================================="
	Write-Host "BuildNumber         :" $BuildNumber
	Write-Host "Environment         :" $Environment
	Write-Host "==================================================================================="
	 
	cmd /c $scriptfile 
}
else {
	Write-Host "Command file not found"
	Exit 1
}

#Preparing the log file: Removing user name and password
$logfile=(Get-ChildItem $Workspace -Recurse -Filter "$($Environment).txt").FullName
gc $logfile | select-string -pattern "CONN L0" -NotMatch | out-file  ("$($Environment)_Execution.log") -Force
$logfile=(Get-ChildItem $Workspace -Recurse -Filter "$($Environment)_Execution.log").FullName

#Setting Status from Error log
$Status="<TD style=""background:'Green'"">SUCCESS</TD>"
if((gc $logfile) -ilike "*ERROR at l*"){
	$Status="<TD style=""background:'red'"">FAILED</TD>"
}

$Deploymentinfo = "<TABLE class='rounded-corner'>"
$Deploymentinfo += "<TR align=center ><TH colspan='2'><B>Deployment Info</B></TH></TR>"
$Deploymentinfo += "<TR><TD><B>Deployment Version</B></TD><TD>$($BuildNumber)</TD></TR>"
$Deploymentinfo +=  "<TR><TD><B>Deploymen Status</B></TD>$Status</TR>"
$Deploymentinfo += "</TABLE>"


#Mailing
$HtmlBody = $HtmlBody -ireplace "#DEPLOYMENTINFO#",$Deploymentinfo
$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
$HtmlBody | Out-File Filesystem::$temphtmlfile
$subject="NINA $($Environment) DB Deployment : $BuildNumber"

SendMailWithAttchments -To  $global:NINADBDeploymentMail -body $HtmlBody -attachment $logfile -subject $subject
Remove-Item FileSystem::$temphtmlfile

