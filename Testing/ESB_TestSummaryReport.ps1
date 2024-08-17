Param
(
[String]$JenkinsWS,
[String]$Environment,
[string]$JobURL
)
Clear-Host

# Load Functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

# Default Declaration
if(!$JenkinsWS){
	$JenkinsWS="\\svw-be-bizd001\E$\Jenkins\workspace\DCORP_ESB_AfterDeploymentTesting"
	$Environment="DCORP"
}

# Variables
$HTMLTemplate=[String]::Format("{0}Notifications\Templates\ESB_AfterDeploymentTestExecutionReport.html",$Global:ScriptSourcePath)
$HTMReportFile=[String]::Format("{0}ESB_TestExecutionSummaryReport.htm",$Global:TempNotificationsFolder)
$Subject="$Environment - ESB After Deployment Test Execution Report"
$HtmlBody=[system.IO.File]::ReadAllLines($HTMLTemplate)

Write-Host "============================================================"
Write-Host "Workspace Path:"$JenkinsWS
Write-Host "Environment   :"$Environment
Write-Host "============================================================"

$TRXFiles=Gci -Path $JenkinsWS -filter "*.trx" |Where{(!$_.PSISContainer)}

$ESB_TestReport="<TABLE class='rounded-corner'>"
$ESB_TestReport+="<TR align=center><TH colspan='5'>$Environment ESB Test Execution Summary</TH></TR>"
$ESB_TestReport+="<TR align=center><TH>Test Report File</TH><TH>Executed Tests</TH><TH>Passed Tests</TH><TH>Failed Tests</TH><TH>Overall Status</TH></TR>"

ForEach($TrxFile in $TRXFiles){
	
	[xml]$XML=(Get-Content Filesystem::$($TrxFile.FullName))
	$Counters=$XML.TestRun.ResultSummary.Counters
	$OverallOutcome=$XML.TestRun.ResultSummary.outcome
	
	$StatusBGColor='green'
	if($OverallOutcome -ine "completed"){
		$StatusBGColor='red'
	}
	$ESB_TestReport+="<TR align=center><TD align=left>$($TrxFile.Name)</TD><TD>$($Counters.executed)</TD><TD>$($Counters.passed)</TD><TD>$($Counters.failed)</TD><TD bgcolor=$StatusBGColor><Font color='white'>$OverallOutcome</font></TD></TR>"

}

$ESB_TestReport+="</TABLE>"

$JobURL=$JobURL+"lastCompletedBuild/testReport/"
$HtmlBody = $HtmlBody -replace "#ENV#",$Environment
$HtmlBody = $HtmlBody -replace "#URL#",$JobURL
$HtmlBody = $HtmlBody -replace "#TESTINFO#",$ESB_TestReport

$HtmlBody|Out-File Filesystem::$HTMReportFile
SendMail -To $global:ESBExecutionUserList -subject $Subject -body $HtmlBody

Remove-Item $HTMReportFile -Force 