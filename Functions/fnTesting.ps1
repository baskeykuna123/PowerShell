$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"
."$ScriptDirectory\fnUtilities.ps1"


Function Execute_NINASoapUIBatFiles(){
PARAM(
	[string]$Environment,
	[string]$Type,
	[string]$JenkinsReportPath
)


#if($env:Environment -ieq "DCORP"){
#	$branch="dev\general"
#	$branchtype="dev"
#}
#else{
#	$branch="staging"
#	$branchtype="staging"
#}


$TestScriptSource=[string]::Format("D:\TestWare\_Business_BackOffice_Nina_{0}",$Environment)
$ReportSource=[string]::Format("D:\ReportsSOAPUI\Functional_Business_BackOffice_Nina_{0}_{1}\",$Type,$Environment)

#Remove Readonly 
RemoveReadOnly -FolderPath $TestScriptSource -Filter $filefilter

$TestBatFile=[string]::Format("Nina_Exec_CommandLine - ST_FUNCT_{0}_{1}.bat",$Type,$Environment)
#Preparing the  Path
$command=Join-Path $TestScriptSource -ChildPath $TestBatFile

if(Test-Path $command){
	Write-Host "==================================================================================="
	Write-Host "TestScript Source    :" $TestScriptSource
	Write-Host "SOAPUI Commmand      :" $command
	Write-Host "==================================================================================="
	cmd.exe /c $command | Write-Host

    $NinaSOAPTestinfo="<TABLE class='rounded-corner'>"
    $NinaSOAPTestinfo+="<TR><TH><B>Test Suite</B></TH><TH><B>Total</B></TH><TH><B>Failed</B></TH><TH><B>ExecutionTime</B></TH>"
    $latestfolder=Get-ChildItem $ReportSource | where {$_.PsIsContainer}| sort LastWriteTime -Descending | Select -First 1
	    get-childitem $latestfolder.FullName -Recurse -filter "TEST-*" | foreach { 
		Copy-Item $_.FullName -Destination $JenkinsReportPath -Force
        $data=[xml] (Get-Content $($_.FullName))
        $data.testsuite | foreach {
		    $bgcolor=""
		    if($($_.failures) -gt '0'){
			    $bgcolor="Red"
		    }
		    $NinaSOAPTestinfo+=[string]::Format("<TR><TD><B>{0}</B></TD><TD>{1}</TD><TD bgcolor='$bgcolor'>{2}</TD><TD>{3}</TD></TR>",$($_.name),$($_.tests),$($_.failures),$($_.time))
		}
	}
$NinaSOAPTestinfo+="</TABLE>"
Return $NinaSOAPTestinfo
}
else{
	Write-Host "No command file to execute"
	return
}

}


Function Execute_CLEVASoapUIBatFiles(){
PARAM(
	[string]$Environment,
	[string]$Type,
	[string]$JenkinsReportPath,
	[String]$ApplicationTestRoot
)


if($Environment -ieq "DCORP"){
	$branch="dev\general"
	$branchtype="dev"
}
else{
	$branch="staging"
	$branchtype="staging"
}


$filter=$Type+"_"+$Environment
$filefilter=$filter+"*.xl*"
$TestScriptSource=[string]::Format("D:\TestWare\_Functional_Business_BackOffice_Cleva_{0}\Cleva_Custom_Services",$Environment)
$ReportSource=[string]::Format("d:\ReportsSOAPUI\Functional_Business_BackOffice_Cleva_{0}\",$filter)
$TestExecutionBatfile=[string]::Format("Functional_Business_BackOffice_Cleva_{0}_{1}.bat",$Environment,$Type)

if($ApplicationTestRoot -ieq 'Technical'){
	$TestScriptSource=[string]::Format("D:\TestWare\_Technical_Business_BackOffice_Cleva_{0}",$Environment)
	$ReportSource=[string]::Format("d:\ReportsSOAPUI\Technical_Business_BackOffice_Cleva_{0}\",$filter)
	$TestExecutionBatfile="Cleva-Exec-CommandLine.bat"
}

#Remove Readonly 
RemoveReadOnly -FolderPath $TestScriptSource -Filter $filefilter

#Preparing the  Path
$command=Join-Path $TestScriptSource -ChildPath $TestExecutionBatfile


if(Test-Path $command){
	Write-Host "==================================================================================="
	Write-Host "TestScript Source    :" $TestScriptSource
	Write-Host "SOAPUI Commmand      :" $TestExecutionBatfile
	Write-Host "==================================================================================="
	Switch($ApplicationTestRoot){
		"Technical" {cmd.exe /c $command $Environment $Type | Write-Host; break}
		 Default {cmd.exe /c $command | Write-Host; break}
	}
}
else{
	Write-Host "Invalid Command file $command"
	Exit 1
}


#Getting the latest Results Folder
$SOAPTestinfo="<TABLE class='rounded-corner'>"
$SOAPTestinfo+="<TR><TH><B>Test Suite</B></TH><TH><B>Total</B></TH><TH><B>Failed</B></TH><TH><B>ExecutionTime</B></TH>"
	$latestfolder=Get-ChildItem $ReportSource | where {$_.PsIsContainer}| sort LastWriteTime -Descending | Select -First 1
		get-childitem $latestfolder.FullName -Recurse -filter "TEST-*.xml" | foreach { 
			Copy-Item $_.FullName -Destination $JenkinsReportPath -Force
			$data=[xml] (Get-Content $($_.FullName))
			$data.testsuite | foreach {
				$bgcolor=""
				if($($_.failures) -gt '0'){
					$bgcolor="Red"
				}
				$SOAPTestinfo+=[string]::Format("<TR><TD><B>{0}</B></TD><TD>{1}</TD><TD bgcolor='$bgcolor'>{2}</TD><TD>{3}</TD></TR>",$($_.name),$($_.tests),$($_.failures),$($_.time))
			}
		}
	$SOAPTestinfo+="</TABLE>"
	Return $SOAPTestinfo
}


Function TestURLs(){
Param(
	[String]$Environment,
	$Testinputfile
)

$patternParameters = '\$\{(.+?)\}'
[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy($Global:serverProxy, $true) 
[system.net.webrequest]::defaultwebproxy.credentials = $Global:secureCred
[system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true
[System.Net.ServicePointManager]::SecurityProtocol= [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
$ApplicationInfo=[xml](get-content FileSystem::$Testinputfile)
if($ApplicationInfo.Tests.URLs.URL){
$ApplicationName=(split-path FileSystem::$Testinputfile -Leaf ).replace("HealthCheckParameters.xml","")

Write-host "===========================$($ApplicationName)========================================"
$Res = @()
$ApplicationInfo.Tests.URLs.URL | foreach {
	
	$parameter=([regex]$patternParameters).Matches($($_.Address))
	$parameterName = $parameter.groups[1].Value
	$parameterNotation = $parameter.groups[0].Value
	$ServerInfo=GetEnvironmentInfo  -Environment $Environment -ServerType "$parameterName"
	foreach($server in $ServerInfo){
		$Uri= ($($_.Address)).replace($parameterNotation,$($server.Name))
		if($Uri -inotlike "*$parameterNotation*"){
		Write-Host 	"Testing URL :" $Uri
		$time = try{
			$request = $null
			## Request the URI, and measure how long the response took.
			$result1 = Measure-Command { $request = Invoke-WebRequest -Uri $uri -UseDefaultCredentials }
			$result1.TotalMilliseconds
		}
		catch{
			$request = $_.Exception.Response
   			$time = -1
		}	  
  	$CurrentResult = [PSCustomObject] @{
		Time = Get-Date;
		Uri = $Uri;
		ExpectedResponse =[int]$($_.Response);
		ActualResponse = [int] $request.StatusCode;
		StatusDescription = $request.StatusDescription;
		ResponseLength = $request.RawContentLength;
		TimeTaken =  $time; 
  	
	 }
	 $Res+=$CurrentResult
	   if($($_.Response) -ne $request.StatusCode)
        {
			write-host ($CurrentResult | Format-List|Out-String)
        }
	}
  }
 
}
if($Res -ne $null)
{  
	$UrlTestResults="<TABLE class='rounded-corner'>"
	$UrlTestResults+="<TR align=center><TH colspan='6'>$ApplicationName</TH></TR>"
	$UrlTestResults+="<TR align=center><TH><B>URL</B></TH><TH><B>Expected Response</B></TH><TH><B>Actual Response</B></TH><TH><B>StatusDescription</B></TH><TH><B>ResponseLength</B></TH><TH><B>TimeTaken</B></TH></TR>"
    Foreach($Entry in $Res)
    {
		
        if($Entry.ActualResponse -ne $Entry.ExpectedResponse)
        {
            $UrlTestResults += "<TR style=""background:'red'"">"
        }
        else
        {
            $UrlTestResults += "<TR>"
        }
        $UrlTestResults += "<TD><B>$($Entry.uri)</B></TD><TD align=center>$($Entry.ExpectedResponse)</TD><TD align=center>$($Entry.ActualResponse)</TD><TD align=center>$($Entry.StatusDescription)</TD><TD align=center>$($Entry.ResponseLength)</TD><TD align=center>$($Entry.timetaken)</TD></TR>"
    }
	$UrlTestResults+="</TABLE>"
}
Write-host "==================================================================="
$OverallTestResult+=$UrlTestResults

return $OverallTestResult
}
}

Function WindowsServiceCheck{
param([String]$Environment,$ApplicationName,$JenkinsURL="",$BuildNumber)
Clear-host

if(!$Environment){
	$Environment="ICORP"
	$Application=""
	$JenkinsURL='http://Jenkins-be:8080/job/Baloise_WindowsServiceStatusCheck/2288/console'
}

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
#$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
#Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#Displaying Script Informationx
Write-host "Script Name :" $MyInvocation.MyCommand
Write-Host "======================================================================="
Write-Host "Input Parameters - "
$($MyInvocation.MyCommand.Parameters) | Format-Table -AutoSize @{ Label = "Parameter Name"; Expression={$_.Key}; }, @{ Label = "Value"; Expression={(Get-Variable -Name $_.Key -EA SilentlyContinue).Value}; }
Write-Host "======================================================================="
write-host "Application:"  $ApplicationName

[xml]$XmlContent = Get-Content FileSystem::$($Global:EnvironmentXml)
$Servers = $XmlContent.SelectNodes("//Environments/Environment[@Name='$($Environment)']/*/*")
$Testinputfile=gci Filesystem::$Global:InputParametersPath -Filter "$ApplicationName*" -File
write-host "$GetTestingParams"
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
$XmlPath=join-path $Global:InputParametersPath  -ChildPath $Testinputfile
write-host "$XmlPath"
[XML]$ServicesContent = get-content -path Filesystem::$Xmlpath
$Servers=$ServicesContent.Tests.Services.Service.server|Select-Object -Unique
$Services=$ServicesContent.Tests.Services.Service.Name
write-host "Service:" $Services
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
$ServiceReport+="<TR align=center><TH colspan='6'>$($ApplicationName)</TH></TR>"
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
		Write-Host "Service Name:"$serviceName
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
	return $ServiceReports
#ExecuteSQLonBIVersionDatabase "EXEC SetApplicationStatus @Application='$ApplicationName',@Environment='$Environment',@TestType='Availability Services',@Status='$($item.State)',@JenkinsURL='$JenkinsURL'"

Write-Host "======================================================================="

$temphtmlfile = join-path $Global:TempNotificationsFolder -childpath "ServiceStatus_Report.htm"

$status="Passed"
if($ServiceReports -ilike "*Red*"){
$status="Failed"
}

#$mailrecipients= GetMailRecipients -ApplicationName $ApplicationName -NotificationType "Deployment" -ParameterXml $ParameterXML

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
#$subject = "$Environment $ApplicationName Deployment Service Test Results for the BuildNumber $BuildNumber : $status"
#SendMail -To $mailrecipients  -body ([string]$HtmlBody) -subject $subject
#SendMailWithoutAdmin -To "Deepak.Gorichela@baloise.be"  -body ([string]$HtmlBody) -subject $subject

Remove-Item FileSystem::$temphtmlfile
}

Function ExecuteSoapUITest($repositoryName,$soapUIProjectFolder,$Environment,$soapUIProjectName,$testSuite){
	$TestReportLocation="$env:WORKSPACE"
	$SoapUIProjectXMLRoot=[String]::Format("{0}\{1}\{2}",$env:WORKSPACE,$repositoryName,$soapUIProjectFolder)
	$cmd = [String]::Format("cmd.exe /C testrunner.bat -s{0} -j -f{1} -o -R""JUnit-Style HTML Report"" -EDefault -GTimeStamp -G= -G""2020-08-31T -G10:12:12.222Z"" {2}\{3}",$testSuite,$TestReportLocation,$SoapUIProjectXMLRoot,$soapUIProjectName)
	Write-host "Command to be executed:"$cmd
}