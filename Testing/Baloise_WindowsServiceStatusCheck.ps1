param([String]$Environment,$ApplicationName="",$JenkinsURL="")

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

Clear-host

if(!$Environment)
{
	$Environment="ICORP"
	$ApplicationName=""
	$JenkinsURL='http://Jenkins-be:8080/job/Baloise_WindowsServiceStatusCheck/2288/console'
}

#Displaying Script Informationx
Write-host "Script Name :" $MyInvocation.MyCommand
Write-Host "======================================================================="
Write-Host "Input Parameters - "
$($MyInvocation.MyCommand.Parameters) | Format-Table -AutoSize @{ Label = "Parameter Name"; Expression={$_.Key}; }, @{ Label = "Value"; Expression={(Get-Variable -Name $_.Key -EA SilentlyContinue).Value}; }
Write-Host "======================================================================="

[xml]$XmlContent = Get-Content FileSystem::$($Global:EnvironmentXml)
$Servers = $XmlContent.SelectNodes("//Environments/Environment[@Name='$($Environment)']/*/*")
$GetTestingParams=gci Filesystem::$Global:InputParametersPath -Filter "*Parameters.xml" -File
$XPath=$XmlContent.SelectNodes("//Environments/Environment[@Name='$($Environment)']")
Switch($Environment){ 
  			"DCORP" {
				$UserName="balgroupit\L001137" 
           		$tempUserPassword ="Basler09"
					 } 
  			"ICORP" {
				$UserName="balgroupit\L001136" 
           		$tempUserPassword ="Basler09"
			} 
  			"ACORP" {
				$UserName="balgroupit\L001135" 
  		   		$tempUserPassword ="h5SweHU8"
				}
		    "PCORP" {$UserName="balgroupit\L001134" 
           			 $tempUserPassword ="9hU5r5druS"}
	}
$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword
$Services=""

ForEach($File in $GetTestingParams){
if (($File -ilike "ESB*") -or ($File -ilike "EAI*") -or ($File -ilike "CentralDataStore*") -or ($File -ilike "Backend*") -or ($File -ilike "MyBaloiseClassic*")){
	write-host "File:"$File
	#$xml=[xml](gc $File.FullName)
	#$Servicenode=$xml.Tests.Services.service
	#if($Servicenode){
	$Application=$($File.Name) -ireplace "HealthCheckParameters.xml"
	write-host "Application:" $Application
#ForEach($Application in $App){
#if (($Application -ilike "ESB") -or ($Application -ilike "EAI") -or ($Application -ilike "CentralDataStore") -or ($Application -ilike "Backend") -or ($Application -ilike "MyBaloiseClassic")){
write-host "$Application"
$Xmlpath=join-path $Global:InputParametersPath  -ChildPath $File

Write-Host "Service check XML file:"$Xmlpath
[XML]$ServicesContent = get-content -path Filesystem::$Xmlpath
$Servers=$ServicesContent.Tests.Services.Service.server|Select-Object -Unique
$Services=$ServicesContent.Tests.Services.Service.Name
ForEach($Server in $Servers){
	$Server=$Server -replace  "\W",""
	$ServerName=$XPath.$Server.Server.Name
	#write-host "Server:"$ServerName

$ServiceReport="<TABLE class='rounded-corner'>"
	$Session = Get-PSSession
	if($Session.Count){
		Exit-PSSession
		$Session | Remove-PSSession 
	}
$ServiceReport+="<TR align=center><TH colspan='6'>$($Application)</TH></TR>"
$ServiceReport+="<TR align=center><TH><B>ServerName</B></TH><TH><B>NAME</B></TH><TH><B>DISPLAYNAME</B></TH><TH><B>STARTMODE</B></TH><TH><B>STATE</B></TH><TH><B>STARTNAME</B></TH></TR>"
ForEach($Serv in $ServerName){	
	write-host "$Serv"
	$RemoteSession = New-PSSession -ComputerName $Serv -Credential $Creds -ErrorAction SilentlyContinue
	Write-Host "======================================================================="
	Write-Host "Getting services list for $Environment Server:"$($Serv)
	Write-Host "======================================================================="

if($RemoteSession){
	$Serviceslist = Invoke-Command -Session $RemoteSession -ScriptBlock {
			param($RService,$RServices) ForEach($RService in $RServices){ Get-WmiObject -Class Win32_Service | where Name -ilike $RService }
	}  -ArgumentList ($Service,$Services)

	if(!$Serviceslist){
		Write-Host "No Services found on this Server..."

	}
	ForEach($item in $Serviceslist){
		$serviceName=$($item.Name)
		Write-Host "Service Name:"$serviceName ::::: ($item.State) --->	($item.StartMode)	
		switch($item.State){
		"Running"	{
						$statuscolor= "Green"
				
					}
		"Stopped"	{
						if($item.StartMode -ieq "Disabled"){
							$statuscolor= "Orange"
							
						}
						elseif($($item.StartMode -ieq "Manual") -and $($serviceName -notlike "*DMS*")){
							$statuscolor= "yellow"
						
						}
						else{
							$statuscolor= "red"
							
						}
					}
		}
		$ServiceReport += "<TR><TD>$Serv</TD><TD>$($item.Name)</TD><TD align=center>$($item.DisplayName)</TD><TD align=center>$($item.StartMode)</TD><TD align=center  style=""background:'$($statuscolor)'"">$($item.State)</TD><TD align=center>$($item.StartName)</TD></TR>"	
		
	}

}
	
	else{
		Write-Host "INFO:PS-session can not be created for server - $($Serv)"
	}



}
}
	$ServiceReport+="</TABLE>"
	$ServiceReports+=$ServiceReport
#if(($($item.State) -ieq "Stopped" -and $item.StartMode -ieq "Auto") -or (!$Serviceslist)){
if($ServiceReport -like"*Red*" -or (!$Serviceslist)){
	ExecuteSQLonBIVersionDatabase "EXEC SetApplicationStatus @Application='$Application',@Environment='$Environment',@TestType='Availability Services',@Status='NOK',@JenkinsURL='$JenkinsURL'"
}
else{
	ExecuteSQLonBIVersionDatabase "EXEC SetApplicationStatus @Application='$Application',@Environment='$Environment',@TestType='Availability Services',@Status='OK',@JenkinsURL='$JenkinsURL'"
}


}
}
Write-Host "======================================================================="

$temphtmlfile = join-path $Global:TempNotificationsFolder -childpath "ServiceStatus_Report.htm"

$status="Passed"
if($ServiceReports -ilike "*Red*"){
$status="Failed"
}
$EnvironmentStatusHTM = [string]::Format("{0}\{1}_WindowsService_Status.htm",$global:EnvironmentHTMLReportLocation,$Environment)
$HtmlBodyStatus = [system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\EnvironmentStatusTest.html" ))
$Timestamp = [datetime]::Now.ToString("dd-MM-yyyy_HHmm")
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#DateTime#",$Timestamp
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#StatusReport#",$ServiceReports
$HtmlBodyStatus | Out-File Filesystem::$EnvironmentStatusHTM -Force

#$ServiceHTMLReport = return $ServiceStatus1
$TemplatefilePath=join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\Service-Report.html"
$HtmlBody = [system.IO.File]::ReadAllLines($TemplatefilePath)
$HtmlBody = $HtmlBody -ireplace "#ReportINFO#",$ServiceReports
$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
$HtmlBody | Out-File Filesystem::$temphtmlfile
$subject = "$Environment Service Test Results : $status"
SendMail -To $global:EnvironmentServiceCheckMail  -body ([string]$HtmlBody) -subject $subject
#SendMailWithoutAdmin -To "uday.turumella@baloise.be"  -body ([string]$HtmlBody) -subject $subject

Remove-Item FileSystem::$temphtmlfile