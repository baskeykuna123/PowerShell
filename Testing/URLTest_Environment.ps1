param($Environment,$MailRecipients,$ApplicationName="",$JenkinsURL="")

#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

Clear-Host

if(!$Environment){
	$Environment="BIOperations"
	$MailRecipients="pankaj.kumarjha@baloise.be"
    $ApplicationName="BITools"
    $JenkinsURL=""
}

$OverallStatus="Successful"

$HtmlBody=[system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\URLTest_Environment.html" ))
$mailtemphtmlfile = [string]::Format("{0}{1}_URLTest_{2}_{3}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$ApplicationName)
#$EnvironmentStatusHTMLTemplate=[String]::Format("{0}Notifications\Templates\EnvironmentStatusTest.html",$Global:ScriptSourcePath)
#$EnvironmentStatusHTMLTemplate=gc $EnvironmentStatusHTMLTemplate
$EnvironmentStatusHTMLTemplate = [system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\EnvironmentStatusTest.html" ))

$Timestamp = Get-Date
if($Environment -ieq "PARAM"){
	$ApplicationName = "ClevaV14"
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

if($ApplicationName -ne "BITools"){
if($ApplicationInfo.Tests.URLs.URL){

	ExecuteSQLonBIVersionDatabase "EXEC SetApplicationStatus @Application='$Appname',@Environment='$Environment',@TestType='Availability URLs',@Status='$status',@JenkinsURL='$JenkinsURL'"

}
}
}

if($testoutputs -ilike '*Red*'){
	$OverallStatus="Failed"
}

$HtmlBody = $HtmlBody -ireplace "#TESTINFO#",$testoutputs
$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
$HtmlBody | Out-File Filesystem::$mailtemphtmlfile

$EnvironmentStatusHTM = [string]::Format("{0}\{1}_URL.htm",$global:EnvironmentHTMLReportLocation,$Environment)
$EnvironmentStatusHTMLTemplate = $EnvironmentStatusHTMLTemplate -ireplace "#DateTime#",$Timestamp
$EnvironmentStatusHTMLTemplate = $EnvironmentStatusHTMLTemplate -ireplace "#StatusReport#",$testoutputs
$EnvironmentStatusHTMLTemplate | Out-File Filesystem::$EnvironmentStatusHTM -Force

$Mailsubject = "$Environment Application URL Test Results : $OverallStatus"
if($env:COMPUTERNAME -ieq "SVW-BE-TESTP003"){
$Mailsubject = 'TESTP003 - ' + $Mailsubject
}
SendMail -To $MailRecipients -subject $Mailsubject -body $HtmlBody
#SendMailWithoutAdmin -To "deepak.gorichela@baloise.be" -subject $Mailsubject -body $HtmlBody

Remove-Item FileSystem::$mailtemphtmlfile