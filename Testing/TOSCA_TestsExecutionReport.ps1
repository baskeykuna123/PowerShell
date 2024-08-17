Param($JenkinsWorkspace,$BundleName,$Environment,$ApplicationName)
CLS
if(!$JenkinsWorkspace){
	$JenkinsWorkspace="\\svw-be-itrace01\d$\Jenkins\workspace\TOSCA_TestExecutor"
	$BundleName="MYBALOISE04-I"
	$ApplicationName="MyBaloiseWebNonLife"
	$Environment="ICORP"
}


#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$TOSCA_TestResultslocation="D:\Jenkins\TOSCA_Results\"

$TOSCATestResultFile= join-path $JenkinsWorkspace -ChildPath "Result.xml"
New-Item $TOSCA_TestResultslocation -Force -ItemType directory
copy-item Filesystem::$($TOSCATestResultFile) -Destination  $TOSCA_TestResultslocation -Force -Recurse
$Timestampfilename=$BundleName+"_Result_"+(Get-Date -Format "yyyyMMdd_hhmm")+".xml"
Rename-Item -Path  "$($TOSCA_TestResultslocation)Result.xml" -NewName $Timestampfilename



#Preparing the HTML template
$HTMLTemplate=[String]::Format("{0}\Notifications\Templates\TOSCATestsExecutionTemplate.html",$Global:ScriptSourcePath)
$HTMlReportFile=[String]::Format("{0}TOSCATestsExecutionReport.htm",$Global:TempNotificationsFolder)
$HtmlBody=[system.IO.File]::ReadAllLines($HTMLTemplate)

#checking if the Result file exists
if(-not (Test-Path Filesystem::$TOSCATestResultFile))
{
	Write-Host "Result File Not found... Aborting..."
	Exit 0
}

Write-Host "==================================================================`n"

[xml]$Resultsfile=(Get-Content -path Filesystem::$TOSCATestResultFile)
$TestSuiteCount=$Resultsfile.testsuites.ChildNodes.Count
Write-host "Result file        : " $TOSCATestResultFile
Write-Host "Total no of Suites : " $TestSuiteCount

if($TestSuiteCount){
$ExecutionStatus="<TABLE class='rounded-corner'>"
$summary=$ExecutionStatus="<TABLE class='rounded-corner'>"
$summary+="<TR align=center><TH>Test suite</TH><TH>Total Tests</TH><TH>Total Passed</TH><TH>Total Failed</TH></TR>"
# Looping test suites to prepare the test resutls
ForEach($suite in $Resultsfile.testsuites.testsuite)
	{
		$suiteName=$suite.Name
		$Testcases=$suite.testcase
		$ExecutionStatus+="<TR align=center><TH colspan='2'>Test Suite : $($suiteName)</TH></TR>"
	  	$ExecutionStatus+="<TR align=center><TH>Testcase</TH><TH>Status</TH></TR>"
	  	Write-Host "SuitName 		:" $suiteName
	  	Write-Host "Testcases count :" $($Testcases.Count)
		if($($Testcases.Count) -eq ""){
			Write-Host "No tests Found..."
			Exit
		}
	   	#Looping test cases to get the status for each test
		$passed=$failed=0
	    ForEach($test in $Testcases){
			$TestStatus = "Passed"	
			$bgcolor="green"
			$passed++
			if($($test.failure.message) -ieq "Test Failure"){
				$TestStatus="Failed"
				$bgcolor="red"
				$failed++
				$passed--
			}
			$totalPassed+=$passed
			$totalFailed+=$failed
			$totaltests+=$Testcases.Count
			$ExecutionStatus+="<TR><td>$($test.name)</td><td bgcolor='$($bgcolor)'>$($TestStatus)</td></TR>"
		}
		$summary+="<TR align=center><TD>$($suiteName)</TD><TD>$($Testcases.Count)</TD><TD bgcolor='green'>$($passed)</TD><TD bgcolor='red'>$($failed)</TD></TR>"
	  	Write-Host "`n=================================================================="#>
	}

$summary+="</TABLE>"
$ExecutionStatus+="</TABLE>"
$HtmlBody=$HtmlBody -replace "#SUMMARY#",$summary
$HtmlBody=$HtmlBody -replace "#TESTINFO#",$ExecutionStatus
$HtmlBody|Out-File FileSystem::$HTMlReportFile

#Sending Mail to all the users in TOSCA disctribution list
$Subject="TOSCA : $($ApplicationName) $($Environment) Test Execution Report  | Bundle : $BundleName"
SendMail -To $global:TOSCADistributionList -subject $Subject -body $HtmlBody
#SendMailWithoutAdmin -To "pankaj.kumarjha@baloise.be" -subject $Subject -body $HtmlBody 

Remove-Item -Path Filesystem::$HTMlReportFile -Force -Recurse
}
else{
	Write-Host "Results file were empty.. Exiting report creation"
}