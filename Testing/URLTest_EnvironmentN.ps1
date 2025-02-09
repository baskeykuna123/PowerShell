param($Environment,$MailRecipients,$ApplicationName="",$JenkinsURL="",$TFSBuildServer,$status, $USER, $Path, $nodes, $BIToolsHealthCheckParameters)

#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}

$TFSAssemblies="Microsoft.TeamFoundation.Build.Client.dll",
"Microsoft.TeamFoundation.Build.Common.dll"



$TFSAssemblyPaths="D:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",

 


"C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",

 


"D:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"

 

 



$Path = "\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\BIToolsHealthCheckParameters.xml"
if($TFSAgentInUse -ieq "True"){
	$Testinputfiles = (get-childitem -$Path -Force -File -Filter *.xml | where {$_.Name -ilike "*BIToolsHealthCheckParameters*" -And $_.Name -NotLike "BITools*"} ).FullName	
}
else{
        $Testinputfiles = [String]::Format("{0}{1}BIToolsHealthCheckParameters.xml",$Global:InputParametersPath,$TFSBuildServer)
}

foreach($Testinputfile in $Testinputfiles){
$ApplicationTFSBuildAgentStatusHTMLTemplate= [System.IO.File]::ReadAllLines
$status="OK"
$applicationoutput= Testinputfile $Testinputfile
$ApplicationInfo=[xml](get-content $Path)
}



$Path = "\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\BIToolsHealthCheckParameters.xml"
[xml]$TFSBuildServer = Get-Content $Path | Convertto-xml -Depth 2 -NoTypeInformation | out-gridview
 
foreach($TFSagentInUse in $Path)
{
$TFSBuildServer = [xml](Get-Content $Path)
$nodes = $TFSBuildServer.SelectNodes('//Details Server')
xml.SelectNodes("Tests/TFSBuildServer[@Name=""Details Server"" and @Service=""agentService""]")
$nodes = $TFSBuildServer.SelectNodes('//agentService')
$nodes = $TFSBuildServer.SelectNodes('//Status')
}
if($TFSagentInUse -eq "True")
{
Write-Host "Details Server :" $TFSBuildServer.DetailsServer
Write-Host "agentService:" $TFSBuildServer.agentService
Write-Host "Status :" $TFSBuildServers.Status
}


$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

Clear-Host

if(!$Environment){
	$Environment="BIOperations"
	$MailRecipients="pankaj.kumarjha@baloise.be"
    $ApplicationName="BITools"
    $BuildAgent="tfs-be.TFSP001"
    $BuildAgentOutput=""
    $JenkinsURL=""
    $USER="Balgroupit\L001146"
}

$OverallStatus="Successful"

$HtmlBody=[system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\URLTest_Environment.html" ))
$mailtemphtmlfile = [string]::Format("{0}{1}_URLTest_{2}_{3}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$ApplicationName)
#$EnvironmentStatusHTMLTemplate=[String]::Format("{0}Notifications\Templates\EnvironmentStatusTest.html",$Global:ScriptSourcePath)
#$EnvironmentStatusHTMLTemplate=gc $EnvironmentStatusHTMLTemplate
$EnvironmentStatusHTMLTemplate = [system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\EnvironmentStatusTest.html" ))

$Timestamp = Get-Date
if($Environment -ieq "PARAM"){
	$ApplicationName = "Cleva"
}

if($ApplicationName -ieq ""){
	$Testinputfiles = (get-childitem -Path FileSystem::$($Global:InputParametersPath) -Force -File -Filter *.xml | where {$_.Name -ilike "*HealthCheckParameters*" -And $_.Name -NotLike "BITools*"} ).FullName	
}
else{
        $Testinputfiles = [String]::Format("{0}{1}HealthCheckParameters.xml",$Global:InputParametersPath,$ApplicationName)
}

foreach($Testinputfile in $Testinputfiles){
$ApplicationURLStatusHTMLTemplate= [System.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath -ChildPath "Notifications\Templates\EnvironmentStatusApplicatonTest.html"))
$status="OK"
$applicationoutput=TestURLs -Environment $Environment -Testinputfile $Testinputfile
$ApplicationInfo=[xml](get-content FileSystem::$Testinputfile)

if($applicationoutput -ilike "*Red*"){
	$status="NOK"
}
	$Appname=($($Testinputfile.Split("\")[-1])).Replace("HealthCheckParameters.xml","")
	$Apphtmlfile = [string]::Format("{0}\{1}_URLTest_{2}_{3}.htm",$global:EnvironmentHTMLReportLocation,$Environment,$Appname,$status)
	
# CREATING URL-TEST REPORT FOR EACH APPLICATIONS
$ApplicationURLStatusHTMLTemplate = $ApplicationURLStatusHTMLTemplate -ireplace "#DateTime#",$Timestamp
$ApplicationURLStatusHTMLTemplate = $ApplicationURLStatusHTMLTemplate -ireplace "#StatusReport#",$applicationoutput
$ApplicationURLStatusHTMLTemplate | Out-File Filesystem::$Apphtmlfile -Force

$testoutputs+= $applicationoutput
$testoutputs+="<BR><BR><BR>"

if($ApplicationName -ne "BITools" -and $Appname -ne "Fireco" -and $Appname -ne "DocumentTransform"){
if($ApplicationInfo.Tests.URLs.URL){
ExecuteSQLonBIVersionDatabase "EXEC SetApplicationStatus @Application='$Appname',@Environment='$Environment',@TestType='Availability URLs',@Status='$status',@JenkinsURL='$JenkinsURL'"
}
}
}

foreach($Testinputfile in $Testinputfiles){
$BuildAgentStatusHTMLTemplate= [System.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath -ChildPath "Notifications\Templates\EnvironmentStatusApplicatonTest.html"))
if($status -ne "Disabled")
{
	Get-Service "vstsagent.tfs-be.DOTNET01"
}
}

if($applicationoutput -ilike "*Red*"){
	$status="NOK"
}
	$BuildServerName=($($Testinputfile.Split("\")[-1])).Replace("HealthCheckParameters.xml","")
	$BuildServerhtmlfile = [string]::Format("{0}\{1}_URLTest_{2}_{3}.htm",$global:EnvironmentHTMLReportLocation,$Environment,$Appname,$status)

# CREATING BUILD AGENT REPORT FOR ALL SERVERS
#$BuildAgentStatusHTMLTemplate = $BuildAgentStatusHTMLTemplate -ireplace "#DateTime#",$Timestamp
#$BuildAgentStatusHTMLTemplate = $BuildAgentStatusHTMLTemplate -ireplace "#StatusReport#",$BuildAgentStatus
#$BuildAgentStatusHTMLTemplate | Out-File Filesystem::$Apphtmlfile -Force

#$testoutputs+= $BuildAgentStatus
#$testoutputs+="<BR><BR><BR>"

#if($testoutputs -ilike '*Red*'){
	#$OverallStatus="Failed"
#}

#if($BuildAgentStatus.Status){
#ExecuteSQLonBIVersionDatabase "EXEC SetBuildAgentStatus @Server='$ServerName',@Environment='$Environment',@TestType='Availability Information',@Status='$status'"
#}


$HtmlBody = $HtmlBody -ireplace "#TESTINFO#",$testoutputs
$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
$HtmlBody | Out-File Filesystem::$mailtemphtmlfile

$EnvironmentStatusHTM = [string]::Format("{0}\{1}_URL.htm",$global:EnvironmentHTMLReportLocation,$Environment)
$EnvironmentStatusHTMLTemplate = $EnvironmentStatusHTMLTemplate -ireplace "#DateTime#",$Timestamp
$EnvironmentStatusHTMLTemplate = $EnvironmentStatusHTMLTemplate -ireplace "#StatusReport#",$testoutputs
$EnvironmentStatusHTMLTemplate | Out-File Filesystem::$EnvironmentStatusHTM -Force
$Mailsubject = "$Environment Application URL Test Results : $OverallStatus"
#SendMail -To $MailRecipients -subject $Mailsubject -body $HtmlBody
SendMailWithoutAdmin -To "uday.turumella@baloise.be, kuna.baskey@baloise.be" -subject $Mailsubject -body $HtmlBody

Remove-Item FileSystem::$mailtemphtmlfile