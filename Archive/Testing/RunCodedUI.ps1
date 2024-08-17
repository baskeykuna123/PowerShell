Param($resultfilepath,$TestType,$Testsetting,$planId,$suiteid,$testserver,$Environment)
#$resultfilepath="F:\result.trx"
#$title="testing"
#$Testsetting="LifeAutomation"
#$planId="270622"
#$suiteid="258239"
#$testserver="TestAutomation"
clear

#Loading Functions(Parameters)
."\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Functions\fnSetGlobalParameters.ps1"

#adding TFS Assemblies
add-type -Path 'D:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Microsoft.TeamFoundation.WorkItemTracking.Client.dll'
add-type -Path 'D:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Microsoft.TeamFoundation.Client.dll'
add-type -Path 'D:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Microsoft.TeamFoundation.VersionControl.Client.dll'
Add-Type -Path 'D:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Microsoft.TeamFoundation.Common.dll'
Add-Type -Path 'D:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\Microsoft.TeamFoundation.TestManagement.Client.dll'
					   					   
					   
#Preparing for the execution of the test cases
$tfsserver="http://tfs-be:9091/tfs/DefaultCollection"
$teamproject="Baloise"
$tfs = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($tfsserver)
$tfs.EnsureAuthenticated()
$testManagementService = $tfs.GetService([Microsoft.TeamFoundation.TestManagement.Client.ITestManagementService])
$testManagementTeamProject = $testManagementService.GetTeamProject($teamproject);
$title= [string]::Format("{0}_{1}_{2}",$TestType,$Environment,[DateTime]::Now.ToString("yyyyMMdd_HHmmss"))


# Clearing content of all CodedUI htm files 
$CodedUIhtmFile = [String]::Format("{0}\{1}_CodedUI_Status.htm",$global:EnvironmentHTMLReportLocation, $Environment) 
$TestHtm = Test-Path FileSystem::$CodedUIhtmFile
$GethtmFile = gci FileSystem::$global:EnvironmentHTMLReportLocation -Recurse | Where-Object{!($_.PSISContainer) -and ($_.Name -ilike "*CodedUI*") }
$TCM2017="D:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\TCM.exe"
$TCM2012="D:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\TCM.exe"

ForEach($Item in $GethtmFile)
{
if($TestHtm -ieq "True")
{
Write-Host "Clearing Content...   ----> " $CodedUIhtmFile
Clear-Content -Path FileSystem::$($Item.FullName) -Force
}
}

#Creating execution runid for each suite
foreach($sid in $suiteid.split(',')){
	$resultsfile=[string]::Format("{0}\{1}_{2}_{3}_{4}_Result.trx",$resultfilepath,$TestType,$Environment,$sid,[DateTime]::Now.ToString("yyyyMMdd_HHmmss"))
	Write-Host "Running TEST-PLAN  : $planId"
	Write-Host "Running TEST-SUITE : $sid "
	Write-Host "Result Trx File    : $resultsfile "
	
	#Creating Test run with the Suite and plan IDs 
	$testRunSubmitResult=& $TCM2017 @("run", "/create", "/title:$title", "/SettingsName:$Testsetting" ,  "/planid:$planId", "/suiteid:$sid", "/configid:10", "/collection:$tfsserver", "/teamproject:$teamproject", "/testenvironment:$testserver", "/include")
	$testRunSubmitResult=$testRunSubmitResult -replace "\.",""
	Write-Host $testRunSubmitResult
	$RunId = $testRunSubmitResult -replace '\D+(\d+)','$1'

while(1)
{
	
	Write-Host "Running $RunId................"
    Start-Sleep -s 300
    $testRun = $testManagementTeamProject.TestRuns.Find($RunId);
    if($testRun.State -eq 'Completed')
    {
	$testRunSubmitResult = & $TCM2017 @("run", "/export", "/id:$RunId", "/collection:$tfsserver", "/teamproject:$teamproject", "/Resultsfile:$resultsfile")
		Write-Host "Test run has completed execution"
        break
    }
    if($testRun.State -eq 'NeedsInvestigation')
    {
	 $testRunSubmitResult = & $TCM2017 @("run", "/export", "/id:$RunId", "/collection:$tfsserver", "/teamproject:$teamproject", "/Resultsfile:$resultsfile")
        Write-Host "Test Execution has failed and needs further investigation.. please go through MTM to get the further details"
        break
    }
    if($testRun.State -eq 'Aborted')
    {
	$testRunSubmitResult = & $TCM2017 @("run", "/export", "/id:$RunId", "/collection:$tfsserver", "/teamproject:$teamproject", "/Resultsfile:$resultsfile")
        Write-Host "Test Execution was aborted... exiting.."
        break 
    }
	$test
}

# Reading TRX file 

[XML]$Content = Get-Content $resultsfile
$FinalResult = $Content.TestRun.ResultSummary   
$TestOutcome = $FinalResult.outcome
if($TestOutcome -ieq "Passed")
{
$BUILD_STATUS="PASSED"
}
else
{
$BUILD_STATUS="FAILED"
}

$BUILD_ID = $env:BUILD_ID
$JOB_URL = $env:JOB_URL
$CodedUIReport = "<TABLE class='rounded-corner'>"
$CodedUIReport += "<TR align=center><TH colspan='2'><B>Test Execution info: SuiteID - $sid</B></TH></TR>"
$CodedUIReport += "<TR><TD><B>Test Type</B></TD><TD><B>$TestType</B></TD></TR>"
$CodedUIReport += "<TR><TD><B>TestPlanID</B></TD><TD><B>$planId</B></TD></TR>"
$CodedUIReport += "<TR><TD><B>SuiteID</B></TD><TD><B>$suiteid</B></TD></TR>"
$CodedUIReport += "<TR><TD><B>Results</B></TD><TD><B>$BUILD_STATUS</B></TD></TR>"
$CodedUIReport += "<TR><TD><B>TestExecution Server</B></TD><TD><B>$testserver</B></TD></TR>"
$CodedUIReport += "<TR><TD><B>Test ResultAnalysis URL </B></TD><TD><B><a href=`"$JOB_URL/test_results_analyzer/`">Test Results</a></B></TD></TR>"
$CodedUIReport += "<TR><TD><B>Test Result Analysis ID </B></TD><TD><B>$BUILD_ID</B></TD></TR>"
$CodedUIReport += "<TR><TD><B>RunId</B></TD><TD><B>$RunId</B></TD></TR>"
$CodedUIReport += "</TABLE>"

# Creating report for codedUI execution status with all the details for Environment check dashboard.
$EnvironmentStatusHTM = [string]::Format("{0}\{1}_CodedUI_Status.htm",$global:EnvironmentHTMLReportLocation,$Environment)
$HtmlBodyStatus = [system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\EnvironmentStatusTest.html" ))
$Timestamp = Get-Date
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#DateTime#",$Timestamp
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#StatusReport#",$CodedUIReport
$HtmlBodyStatus | Out-File Filesystem::$EnvironmentStatusHTM -Force -Append
}