param(
	[String]$BundleName,
	[string]$Environment,
	[string]$ApplicationName,
	[string]$pretestbundle,
	$JenkinsWorkspace,
	$JenkinsCurrentRunURL,
	$SubjectPrefix=""
	
)
CLS



#Loading Functions
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

Function UpdateBundle(){
	param(
	[String]$BundleName,
	[string]$Environment,
	[string]$ApplicationName	
	
	)
	if(!$Environment){
	$Environment="ICORP"
}


switch ($Environment) 
      { 
	    "DCORP" { $ToscEnvironment="DTOS"}
        "ICORP" { $ToscEnvironment="ITOS"}
		"ACORP" { $ToscEnvironment="ATOS"}
		"PCORP" { $ToscEnvironment="PRD"}
		"MIG"   { $ToscEnvironment="MIGTOS"
				  $Environment="DATAMIG"
				}
		"MIG2"  { $ToscEnvironment="MIG2TOS"}
		"MIG3"  { $ToscEnvironment="MIG3TOS"}
		"MIG4"  { $ToscEnvironment="MIG4TOS"}
		"PRED"  { $ToscEnvironment="PREDTOS"}
		"EMRG"  { $ToscEnvironment="EMRGTOS"}
	  }




$ApplicationName="CLEVA-UI"

#copy clients for CLEVA only
if($ApplicationName -ieq "CLEVA-UI" -or $ApplicationName -ieq "MC" -or $ApplicationName -ieq "MorningCheck"){
    Write-Host "Environment    : " $Environment
	$ClientSource=[string]::Format("{0}\{1}-Current-Tosca",$global:ClevaCitrixClientSourcePath,$Environment)
	$Workspaceshare=[string]::Format("{0}TOSCA_WORKSPACES\Clients\{1}\",$global:TranferFolderBase,(GetClevaEnvironment -Environment $ToscEnvironment))
    
    $sourcefile=Get-ChildItem $ClientSource
    $destfile=Get-ChildItem $ClientSource
    
    
       if ((($sourcefile.foreach{ Get-FileHash $_.FullName }).Hash -and ($destfile.foreach{ Get-FileHash $_.FullName }).Hash)){
        write-host "equal"
    }

    if($env:COMPUTERNAME -ieq "SVW-BE-TESTP002"){
        $serverlist=($global:TestFarm2Servers)
		write-host "TestFarmServer : " $global:TestFarm2Servers
    }
    else {
        $serverlist=($global:TestFarm1Servers)
		write-host "TestFarmServer : " $global:TestFarm1Servers
        Get-ChildItem -Path Filesystem::$Workspaceshare -Include * | remove-Item -recurse -Force 
	    Copy-Item Filesystem::"$($ClientSource)\*" -Destination Filesystem::$Workspaceshare -Force -Recurse
        Write-Host "Updating clients on the share"
	    Write-Host "Client Source  : " $ClientSource
	    Write-Host "Workspace Share: " $Workspaceshare
    }
	
	if(Test-Path Filesystem::$ClientSource){
		Write-Host "`r`n Updating the latest clients for : $($Environment)"
		Foreach($server in $serverlist.split(',')){
			$TestServerClientPath=[string]::Format("\\{0}\c$\Program Files (x86)\Cleva\BE\CLEVA_{1}\",$server,$ToscEnvironment)
			Write-Host "Updating Client on : " $server
			Write-Host "Client Path        : " $TestServerClientPath
			Write-Host "Removing Client........"
			Get-ChildItem -Path $TestServerClientPath -Include * | remove-Item -recurse -Force
			Write-Host "Copying New Client......."
			Copy-Item "$($ClientSource)\*" -Destination $TestServerClientPath -Force -Recurse
		}
	}
}


# Read config and set element in config 
 $TestconfigXMLPath=$global:TOSCATestExecutionConfig
 
        $TestconfigXMLPath="C:\Program Files (x86)\TRICENTIS\Tosca Testsuite\ToscaCommander\ToscaCI\Client\CITestExecutionConfiguration.xml"
 
$XML=[xml](Get-Content FileSystem::$TestconfigXMLPath)
$TestEventElement=$XML.SelectSingleNode("//testConfiguration/TestEvents/TestEvent")

$TestEventElement.InnerText = $BundleName
$XML.Save($TestconfigXMLPath)

Write-Host "`r`n`r`n========================================================="
Write-Host "Executing Bundle=" $BundleName
Write-Host "========================================================="

}
Function RunTest(){
	& "C:\Program Files (x86)\TRICENTIS\Tosca Testsuite\ToscaCommander\ToscaCI\Client\ToscaCIClient.exe" -m distributed -c "c:\Program Files (x86)\TRICENTIS\Tosca Testsuite\ToscaCommander\ToscaCI\Client\CITestExecutionConfiguration.xml" -t junit -r "$($JenkinsWorkspace)\Result.xml"
}
Function SendResult(){
	param(
	[String]$BundleName,
	[string]$Environment,
	[string]$ApplicationName,
	[string]$pretestbundle,
	$JenkinsWorkspace,
	$JenkinsCurrentRunURL,
	$SubjectPrefix=""
	
	)
	if(!$JenkinsWorkspace){
	$JenkinsWorkspace="D:\Shivaji\"
	$JenkinsCurrentRunURL="http://Jenkins-be:8080/job/TOSCA_TestExecutor_DC3/1419/"
	$BundleName="MCHECK-I"
	$ApplicationName="CLEVA"
	$Environment="DCORP"
	}
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
	$MailRecipients='#BE_BBE_Tosca_MorningCheck_ICORP@Baloise.be'
}
$Subject="$($SubjectPrefix) TOSCA : $($ApplicationName) $($Environment) | $($BundleName) | PassRate - $($totalPassPercentage)%"

SendMail -To $MailRecipients -subject $Subject -body $HtmlBody
Remove-Item -Path Filesystem::$HTMlReportFile -Force -Recurse
}

else{
	Write-Host "Results file were empty.. Exiting report creation"
}
return $totalPassPercentage
}


if($pretestbundle){
write-host "pretestbundle"
UpdateBundle -BundleName $pretestbundle -Environment $Environment -ApplicationName $ApplicationName
RunTest
#SendResult -JenkinsWorkspace $JenkinsWorkspace -BundleName $pretestbundle -Environment $Environment -ApplicationName $ApplicationName -JenkinsCurrentRunURL $JenkinsCurrentRunURL -SubjectPrefix $SubjectPrefix
$totalPassPercentage = SendResult -JenkinsWorkspace $JenkinsWorkspace -BundleName $pretestbundle -Environment $Environment -ApplicationName $ApplicationName -JenkinsCurrentRunURL $JenkinsCurrentRunURL -SubjectPrefix $SubjectPrefix
if($totalPassPercentage -eq '100'){
UpdateBundle -BundleName $BundleName -Environment $Environment -ApplicationName $ApplicationName
RunTest
SendResult -JenkinsWorkspace $JenkinsWorkspace -BundleName $BundleName -Environment $Environment -ApplicationName $ApplicationName -JenkinsCurrentRunURL $JenkinsCurrentRunURL -SubjectPrefix $SubjectPrefix
}
else{
Write-Host "pre test failed"
write-host $totalPassPercentage

}
}
else{
UpdateBundle -BundleName $BundleName -Environment $Environment -ApplicationName $ApplicationName
RunTest
SendResult -JenkinsWorkspace $JenkinsWorkspace -BundleName $BundleName -Environment $Environment -ApplicationName $ApplicationName -JenkinsCurrentRunURL $JenkinsCurrentRunURL -SubjectPrefix $SubjectPrefix
}
