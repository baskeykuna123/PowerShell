param($Environment,$ApplicationName,$BuildNumber,$NotificationType,$PlannedTime,$subjectPrefix="",$JenkinsURL="")
Clear-Host

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if((!$BuildNumber) -and ($Application -ine 'MDM')){
	$BuildNumber = ""
	$Environment = "DCORP"
	$ApplicationName="NINA"
	$NotificationType="Completed"
	$PlannedTime="22:00"
	$subjectPrefix="[V14]"
        $JenkinsURL='http://jenkins-be:8080/view/20.Deployments_NINA/view/01.DCORP/job/DCORP_NINA_DeploymentTest/2077/console'
}

Write-Host "================================================================================="
Write-Host "Application Name  : " $ApplicationName
Write-Host "Environment       : " $Environment
Write-Host "Version           : " $BuildNumber
Write-Host "NotificationType  : " $NotificationType
Write-Host "================================================================================="


$HTMLTemplateFilePath=join-path $($Global:ScriptSourcePath)  -ChildPath "Notifications\Templates\Application_Deployment.html"
$HtmlBody=get-content Filesystem::$HTMLTemplateFilePath
$temphtmlfile = [string]::Format("{0}\{1}_Deployment_{2}_{3}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$ApplicationName)
$Deploymentinfo= GetVersionforNotification -Application $ApplicationName -Version $BuildNumber
$attachments=""
$testoutput=""
$testoutput1=""

if(($NotificationType -ieq "Completed")){
	if($ApplicationName -ieq "CLEVA"){
		$attachments=GetClevaReleaseNotes -version $BuildNumber	
	}
	
	$Testinputfile=[String]::Format("{0}{1}HealthCheckParameters.xml",$Global:InputParametersPath,$ApplicationName)
	
	if(CheckifTFSBuild -BuildNumber $BuildNumber -ApplicationName $ApplicationName){
		$packagefolder=GetPackageSourcePathforTFSBuilds -BuildNumber $BuildNumber -ApplicationName $ApplicationName
	    $HealthCheckFileName = join-path $packagefolder -ChildPath ($applicationName + "HealthCheckParameters.xml")
		$ParameterXML=join-path $packagefolder -ChildPath ($applicationName + "DeploymentParameters_Resolved.xml")
	    $Testinputfile=$HealthCheckFileName
		Write-Host "TFS build found: URLs will be fetched from Healthcheck parameters.xml"
	}
	
	$testoutput = TestURLs -Environment $Environment -Testinputfile $Testinputfile
	#$testoutput1 = WindowsServiceCheck -Environment $Environment
	if($testoutput -ilike "*red*"){
		$NotificationType="FAILED"
	}
	else{
		$NotificationType="SUCCESSFUL"
	}
}
if($NotificationType -ne "Planned"){
ExecuteSQLonBIVersionDatabase "EXEC SetApplicationStatus @Application='$ApplicationName',@Environment='$Environment',@TestType='Deployment URLs',@Status='$NotificationType',@JenkinsURL='$JenkinsURL'"
}

#preparing the HTML Body to the mail
$HtmlBody = $HtmlBody -ireplace "#SOAPTESTINFO#",""
$HtmlBody = $HtmlBody -ireplace "#DEPLOYMENTINFO#",$Deploymentinfo
$HtmlBody = $HtmlBody -ireplace "#DEPLOYMENTTESTINFO#",$testoutput
#$HtmlBody = $HtmlBody -ireplace "#DEPLOYMENTTESTServices#",$testoutput1
$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
$HtmlBody | Out-File Filesystem::$temphtmlfile



$Mailsubject = "$subjectPrefix $ApplicationName $Environment Deployment - $BuildNumber : $NotificationType"
if($NotificationType -ieq "Planned"){
	$date=Get-Date -Format "yyyy-MM-dd"
	$Mailsubject = "$subjectPrefix $ApplicationName $Environment Deployment - $BuildNumber : $NotificationType @ $date - $PlannedTime"
}

$mailrecipients= GetMailRecipients -ApplicationName $ApplicationName -NotificationType "Deployment" -ParameterXml $ParameterXML

if(!$attachments){
	SendMail -To  $mailrecipients -body $HtmlBody -subject $Mailsubject
	#SendMailWithoutAdmin -To  "pankaj.kumarjha@baloise.be" -body $HtmlBody -subject $Mailsubject
}
else {
	SendMailWithAttchments -To  $mailrecipients -body $HtmlBody -attachment $attachments -subject $Mailsubject
}
Remove-Item FileSystem::$temphtmlfile