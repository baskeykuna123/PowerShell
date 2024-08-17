Param($JenkinsWorkspace,$BundleName,$Environment,$ApplicationName,$JenkinsCurrentRunURL,$SubjectPrefix="")
CLS
if(!$JenkinsWorkspace){
	$JenkinsWorkspace="D:\Shivaji\"
	$JenkinsCurrentRunURL="http://Jenkins-be:8080/job/TOSCA_TestExecutor_DC3/1419/"
	$BundleName="MCHECK-I"
	$ApplicationName="CLEVA"
	$Environment="DCORP"
}


#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop


$TOSCATestResultFile= join-path $JenkinsWorkspace -ChildPath "Result.xml"
Write-Host "TOSCA Result File : " $TOSCATestResultFile
copy-item $TOSCATestResultFile -Destination Filesystem::"$($global:TOSCATestResultsShare)" -Force -Recurse
$Timestampfilename=[string]::Format("Result_{0}_{1}.xml",(Get-Date -Format "yyyyMMdd_hhmm"),$BundleName)
Rename-Item -Path  Filesystem::"$($global:TOSCATestResultsShare)\Result.xml" -NewName $Timestampfilename
$JunitReportsURL=$JenkinsCurrentRunURL  + "/junit-reports-with-handlebars/testSuitesOverview.html"

#Preparing the HTML template
$HTMLTemplate=[String]::Format("{0}\Notifications\Templates\TOSCA_TestExecutionReport_MailTemplate.html",$Global:ScriptSourcePath)
$HTMlReportFile=[String]::Format("{0}TOSCATestsExecutionReport.htm",$Global:TempNotificationsFolder)
$HtmlBody=[system.IO.File]::ReadAllLines($HTMLTemplate)

#checking if the Result file exists
if(-not (Test-Path Filesystem::$TOSCATestResultFile))
{
	Write-Host "Result File Not found... Aborting..."
	Exit 0
}


[xml]$Resultsfile=(Get-Content -path Filesystem::$TOSCATestResultFile)
$TestSuiteCount=$Resultsfile.testsuites.ChildNodes.Count
Write-host "Result file        : " $TOSCATestResultFile
Write-Host "Total no of Suites : " $TestSuiteCount

if($TestSuiteCount){
	
	# Looping test suites to prepare the test resutls
	$Res = @()
	$Resultsfile.testsuites.testsuite[0]

ForEach($suite in $Resultsfile.testsuites.testsuite){
		if(([int]$suite.tests) -eq ""){
			Write-Host "No tests Found..."
			Exit
		}
		[int]$tests=$suite.tests
		[int]$failed=$suite.failures
		[int]$passed=$tests - $failed
		[int]$averagesecs=(([int]$suite.time)/$tests)
		$PassPercentage=[System.Math]::Round((($passed /$tests)*100),0)
		$FailPercentage=[System.Math]::Round((($failed/$tests)*100),0)
	  	$Res += [PSCustomObject] @{
			SuiteName = $suite.Name
			NoOfTestcases=$tests
			NoOfPassed=$passed
			NoOfFailed=$failed
			PassPercentage=$PassPercentage
			FailPercentage=$FailPercentage
			TimePersuiteinSecs=$suite.time
			AverageTimePerSuiteinSecs=$averagesecs
	 	}
}		


[int]$totaltests=[int]$totalpassedtests=[int]$totalfailedtests=[int]$totalFailPercentage=[int]$TotalTestsuites=[int]$totalavgsecs=[int]$totalsecs=0
if($Res -ne $null){  
    Foreach($Entry in $Res){
		$totalTestsuites++
		$totaltests+=$Entry.NoOfTestcases
		$totalpassedtests+=$Entry.NoOfPassed
		$Totalfailedtests+=$Entry.NoOfFailed
		$totalsecs+=$Entry.TimePersuiteinSecs
		$totalavgsecs+= $Entry.AverageTimePerSuiteinSecs	
		
	}
}

$totalduration=("{0:hh\:mm\:ss}" -f  [timespan]::FromSeconds($totalsecs))
$totalavgduration=("{0:hh\:mm\:ss}" -f  [timespan]::FromSeconds($totalavgsecs/$totalTestsuites))
$totalPassPercentage=[System.Math]::Round((($totalpassedtests/$totaltests)*100),0)
$totalFailPercentage=[System.Math]::Round((($Totalfailedtests/$totaltests)*100),0)
$summary="<TABLE class='rounded-corner'>"
$passedcolor="green"
$Summaryfontstyle="font-size: 18px;font-weight: bold"
$testdetails=""
$Failedcolor=""
Foreach($Entry in $Res){
	if($($Entry.NoOfFailed)  -ge 1){
		$Failedcolor="red"
	}
	else{
		$Failedcolor=""
	}
	$duration=("{0:hh\:mm\:ss}" -f  [timespan]::FromSeconds($Entry.TimePersuiteinSecs))
	$avgduration=("{0:hh\:mm\:ss}" -f  [timespan]::FromSeconds($Entry.AverageTimePerSuiteinSecs))
	$testdetails+="<TR align=center><TD align=left>$($Entry.SuiteName)</TD><TD>$($Entry.NoOfTestcases)</TD><TD bgcolor='$passedcolor'>$($Entry.NoOfPassed)</TD><TD bgcolor='$Failedcolor'>$($Entry.NoOfFailed)</TD><TD>$($Entry.PassPercentage)%</TD><TD>$($Entry.FailPercentage)%</TD><TD>$($duration)</TD><TD>$($avgduration)</TD></TR>"
}
$summary+="<TR align=center><TH>Test suite</TH><TH>Total Tests</TH><TH>#Passed</TH><TH>#Failed</TH><TH>Pass Rate</TH><TH>Fail Rate</TH><TH>Duration</TH><TH>Time/Test</TH></TR>"
$summary+="<TR align=center><TD style='$Summaryfontstyle'>Summary</TD><TD  style='$Summaryfontstyle'>$totaltests</TD  style='f$Summaryfontstyle'><TD  bgcolor='$passedcolor' style='$Summaryfontstyle'>$($totalpassedtests)</TD><TD  bgcolor='$Failedcolor' style='$Summaryfontstyle'>$($totalfailedtests)</TD><TD style='$Summaryfontstyle'>$($totalPassPercentage)%</TD><TD style='$Summaryfontstyle'>$($totalFailPercentage)%</TD><TD  style='$Summaryfontstyle'>$totalduration</TD><TD  style='$Summaryfontstyle'>$totalavgduration</TD></TR>"
$summary+=$testdetails
$summary+="</TABLE>"
$HtmlBody=$HtmlBody -replace "#SUMMARY#",$summary
$HtmlBody=$HtmlBody -replace "#JOBURL#",$JunitReportsURL

$HtmlBody|Out-File FileSystem::$HTMlReportFile

#Sending Mail to all the users in TOSCA disctribution list
#added for TOSCA Morning CHecks 
$MailRecipients=$global:TOSCADistributionList
if($ApplicationName -ieq "MC"){
	$MailRecipients='#BE_BBE_Tosca_MorningCheck@Baloise.be'
}
$Subject="$($SubjectPrefix) TOSCA : $($ApplicationName) $($Environment) | $($BundleName) | PassRate - $($totalPassPercentage)%"
SendMail -To $MailRecipients -subject $Subject -body $HtmlBody
Remove-Item -Path Filesystem::$HTMlReportFile -Force -Recurse
}
else{
	Write-Host "Results file were empty.. Exiting report creation"
}