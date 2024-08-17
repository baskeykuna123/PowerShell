Param($Environment,$Type,$Reportpath,$JenkinsURL="")

Clear-Host

if(!$Environment){
	$Environment="DCORP"
	$Type="SMOKE"
	$Reportpath="D:\test\"
        $JenkinsURL="http://jenkins-be:8080/job/DCORP_NINA_SOAPUITest/783/console"
}




#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


#Displaying Script Information
Write-host "Script Name :" $MyInvocation.MyCommand
Write-host "=======================Input Parameters======================================="
$($MyInvocation.MyCommand.Parameters) | Format-Table -AutoSize @{ Label = "Parameter Name"; Expression={$_.Key}; }, @{ Label = "Value"; Expression={(Get-Variable -Name $_.Key -EA SilentlyContinue).Value}; }
Write-host "=======================Input Parameters================================================="


#switch($Type){
#	"SMOKE" {$Type="SMK" }
#	"REGRESSION" {$Type="REG"}
#}

#Execute the tests
$TestResultsHtml=Execute_NINASoapUIBatFiles -Environment $Environment -Type $Type -JenkinsReportPath $Reportpath
$status="NOK"
if($TestResultsHtml -inotlike "*Red*"){
$status="OK"
}

#Preparing Mail body 
$HtmlBody=get-content Filesystem::$Global:SoapUINinaMailTemplateFile
$temphtmlfile = [string]::Format("{0}\{1}_SOAPUI_{2}_{3}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$ApplicationName)
$HtmlBody = $HtmlBody -ireplace "#TYPE#",$Type
$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
$HtmlBody = $HtmlBody -ireplace "#TESTEXECUTION#",$TestResultsHtml
$HtmlBody | Out-File Filesystem::$temphtmlfile

ExecuteSQLonBIVersionDatabase "EXEC SetApplicationStatus @Application='NINA',@Environment='$Environment',@TestType='SoapUI Functional $Type',@Status='$status',@JenkinsURL='$JenkinsURL'"

#Preparing HTML for Environment Dashboard
$EnvironmentStatusHTM = [string]::Format("{0}\{1}_SOAPUININA_{2}.htm",$global:EnvironmentHTMLReportLocation,$Environment,$Type)
$HtmlBodyStatus = [system.IO.File]::ReadAllLines($Global:EnvironmentStatusTemplate)
$Timestamp = [datetime]::Now.ToString("dd-MM-yyyy_HHmm")
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#DateTime#",$Timestamp
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#StatusReport#",$TestResultsHtml
$HtmlBodyStatus | Out-File Filesystem::$EnvironmentStatusHTM -Force

#Mail
$Mailsubject = "NINA SOAPUI $Type Testing $Environment"
SendMail -To $global:NiNaSOAPUITestExecutionMailList  -body $HtmlBody -subject $Mailsubject

#Cleanup
Remove-Item FileSystem::$temphtmlfile