PARAM([String]$MailRecipients,$StartDate,$EndDate)
clear

# get an instance of TfsTeamProjectCollection
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")  
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Build.Client")  
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Build.Common") 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.WorkItemTracking.Client") 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.TestManagement.Client") 
clear
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$TFS=[Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($global:TFSServer)
$month=Get-Date -Format "M"
$dropfilepath=[string]::Format('E:\Buildteam\Temp\{0}_DailyTestExecutionStatus.csv',$month)
# get an instance of WorkItemStore
$Test = $TFS.GetService([Microsoft.TeamFoundation.TestManagement.Client.ITestManagementService]);
$TeamProject=$Test.GetTeamProject("Baloise")
$date=Get-Date -Format "dd/MM/yyyy"
$testruns=$Test.QueryTestRuns("select * from TestRun where LastUpdated='$date'")
$header="TestRunID,TestRunTitle,Iteration,Tester,StartedDate,CompletedDate,$run.IsAutomated,$run.State,TestcaseID,TestCaseTitle,TestCaseIteration"
Add-Content -Path $dropfilepath -Value  $header

foreach($run in $testruns){
	[Microsoft.TeamFoundation.TestManagement.Client.ITestCaseResultCollection]$testcases=$run.QueryResults()
	foreach($testcase in $testcases){
		if($testcase.TestCaseId -ne 0){
			$test=$TeamProject.TestCases.Find($testcase.TestCaseId)
			$Runinfo=[string]::Format('"{0}","{1}","{2}","{3}","{4}","{5}","{6}","{7}","{8}","{9}","{10}"',$run.id,$run.Title,$run.Iteration,(($run.LastUpdatedByName).replace(',',' ')),$run.DateStarted,$run.DateCompleted,$run.IsAutomated,$run.State,$testcase.TestCaseId,$testcase.TestcaseTitle,$test.WorkItem.IterationPath)
			Add-Content -Path $dropfilepath -Value  $Runinfo
			$test=$TeamProject.TestCases.Find($testcase.TestCaseId)
			$test.Data.Tables[0]
		}
	}	
}
$MailRecipients="Shivaji.pai@baloise.be"
$subject="Test Execution per user info - $month"
$bdy="C's<BR><BR>Pleased find the Daily test Execution per Tester Report Attached <BR><BR>Regards<BR>TFS Admin"
SendMailWithAttchments -attachment $dropfilepath -To $MailRecipients -subject $subject -body $bdy



