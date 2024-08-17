Param
(
[String]$Environment,
[String]$JenkinsWorkspace
)
Clear-Host

# Loading Functions 
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if(!$JenkinsWorkspace){
	$Environment="DCORP"
	$JenkinsWorkspace= "\\svw-be-bizd001\E$\Jenkins\workspace\DCORP_ESB_AfterDeploymentTesting"
}

# Variables
$HTMLTemplate=[String]::Format("{0}Notifications\Templates\ESB_AfterDeploymentTestExecutionReport.html",$Global:ScriptSourcePath)
$HTMReportFile=[String]::Format("{0}ESB_AfterDeploymentTestExecutionReport.htm",$Global:TempNotificationsFolder)
$Subject="$Environment - ESB After Deployment Test Execution Report"
$HtmlBody=[system.IO.File]::ReadAllLines($HTMLTemplate)

$TRXFiles=Gci -Path $JenkinsWorkspace -filter "*.trx" |Where{(!$_.PSISContainer)}

$ESB_TestReport="<TABLE class='rounded-corner'>"
$ESB_TestReport+="<TR align=center><TH colspan='2'>$Environment ESB Test Execution Report</TH></TR>"
ForEach($TrxFile in $TRXFiles)
{	
	Write-Host "========================================================================================"
	Write-Host "TRX File:" $TrxFile
	Write-Host "`tAdding test details to the report....."
	$ESB_TestReport+="<TR align=center><TH colspan='2'>TRX File - $TrxFile</TH></TR>"
	$ESB_TestReport+="<TR align=center><TH>Test Name</TH><TH>Test Status</TH></TR>"	

	[xml]$TRXContent=Get-Content $TrxFile.FullName

	$TestNames=$TRXContent.TestRun.Results.UnitTestResult
	
	ForEach($item in $TestNames)
	{	
		
		Write-Host "`tChecking Testcases ..."
		Write-Host "`t Test Name:" $item.testName
		
		$TestDetails=[PSCustomObject]@{
		TestName=$item.testName
		TestStatus=$item.outcome
		TestDuration=$item.duration
		}
		
		$TestStatus=$TestDetails.TestStatus
		$TestName=$TestDetails.TestName
		$TestDuration=$TestDetails.TestDuration
		
		$bgColor='green'
		if($TestStatus -ieq "Failed"){
			$bgColor='red'
		}
		$Statusfont='white'
		$ESB_TestReport+="<TR align=center><TD>$TestName</TD><TD bgcolor='$($bgColor)'><font color=$Statusfont>$TestStatus</font></TD></TR>"
	}
	Write-Host "==================================================================================="
	
}

$ESB_TestReport+="</TABLE>"
$HtmlBody = $HtmlBody -replace "#ENV#",$Environment
$HtmlBody = $HtmlBody -replace "#TESTINFO#",$ESB_TestReport

$HtmlBody|Out-File Filesystem::$HTMReportFile
SendMail -To $global:ESBExecutionUserList -subject $Subject -body $HtmlBody