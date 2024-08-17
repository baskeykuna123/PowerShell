Param($Environment,$Type,$Reportpath,$ApplicationTestRoot,$JenkinsURL="")

Clear-Host

if(!$Environment){
	$Environment="DCORP"
	$Type="SMK"
	$Reportpath="D:\test\"
	$ApplicationTestRoot
	$JenkinsURL='http://jenkins-be:8080/job/SOAPUI_CLEVA_TechnicalTest/229/console'
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


#Execute the tests
$TestResultsHtml=Execute_CLEVASoapUIBatFiles -Environment $Environment -Type $Type -JenkinsReportPath $Reportpath -ApplicationTestRoot $ApplicationTestRoot
$status="OK"

ExecuteSQLonBIVersionDatabase "EXEC SetApplicationStatus @Application='CLEVA',@Environment='$Environment',@TestType='SoapUI $ApplicationTestRoot $TYPE',@Status='$status',@JenkinsURL='$JenkinsURL'"

if($TestResultsHtml -ilike "*Red*"){
	$status="NOK"
}

if($ApplicationTestRoot -ieq "Functional"){
	#Preparing Mail body 
	$HtmlBody=get-content Filesystem::$Global:SOAPUIMailTemplateFile
	$temphtmlfile = [string]::Format("{0}\{1}_SOAPUI_{2}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"))

	$HtmlBody = $HtmlBody -ireplace "#TYPE#",$Type
	$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
	$HtmlBody = $HtmlBody -ireplace "#TESTEXECUTION#",$TestResultsHtml
	$HtmlBody | Out-File Filesystem::$temphtmlfile

	#Mail
	$Mailsubject = "SOAPUI $Type Testing $Environment"

	SendMail -To $global:SOAPUITestExecutionMailList  -body $HtmlBody -subject $Mailsubject
	#SendMailWithoutAdmin -To "pankaj.kumarjha@baloise.be,uday.turumella@baloise.be"  -body $HtmlBody -subject $Mailsubject

	#Preparing HTML for Environment Dashboard
	$EnvironmentStatusHTM = [string]::Format("{0}\{1}_SoapUISMOKETest_Cleva_{2}.htm",$global:EnvironmentHTMLReportLocation,$Environment,$status)
	$SoapUIHTM = [string]::Format("{0}\{1}_SOAPUI_{2}.htm",$global:EnvironmentHTMLReportLocation,$Environment,$Type)
	$HtmlBodyStatus = [system.IO.File]::ReadAllLines($Global:EnvironmentStatusTemplate)
	$Timestamp = [datetime]::Now.ToString("dd-MM-yyyy_HHmm")
	$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#DateTime#",$Timestamp
	$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#StatusReport#",$TestResultsHtml
	$HtmlBodyStatus | Out-File Filesystem::$EnvironmentStatusHTM -Force
	$HtmlBodyStatus | Out-File FileSystem::$SoapUIHTM -Force
	
	#Cleanup
	Remove-Item FileSystem::$temphtmlfile
}
Else{
	Write-Host "INFO:$Environment $Type test is completed but has no test reports"
}


