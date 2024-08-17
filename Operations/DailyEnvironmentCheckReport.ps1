param(
$DCORPMwebURLStatus,
$ICORPMwebURLStatus,
$ACORPMwebURLStatus,
$DCORPBackendURLStatus,
$ICORPBackendURLStatus,
$ACORPBackendURLStatus,
$DCORPCdsURLStatus,
$ICORPCdsURLStatus,
$ACORPCdsURLStatus,
$DCORPClevaURLStatus,
$ICORPClevaURLStatus,
$ACORPClevaURLStatus,
$DCORPClassicURLStatus,
$ICORPClassicURLStatus,
$ACORPClassicURLStatus,
$DCORPCdsServiceStatus,
$ICORPCdsServiceStatus,
$ACORPCdsServiceStatus,
$DCORPBackendServiceStatus,
$ICORPBackendServiceStatus,
$ACORPBackendServiceStatus,
$DCORPMnetServiceStatus,
$ICORPMnetServiceStatus,
$ACORPMnetServiceStatus,
$ICORPTalkClientStatus,
$ACORPTalkClientStatus,
$ICORPClassicClientStatus,
$ACORPClassicClientStatus,
$DCORPClevaClientStatus,
$ICORPClevaClientStatus,
$ACORPClevaClientStatus,
$DCORPNinaURLStatus,
$ICORPNinaURLStatus,
$ACORPNinaURLStatus,
$DCORPMFCheckStatus,
$ICORPMFCheckStatus,
$ACORPMFCheckStatus,
$DCORPSoapUIStatus,
$ICORPSoapUIStatus,
$ACORPSoapUIStatus,
$ICORPCodedUITests,
$ACORPCodedUITests,
$DCORPEsbServiceStatus,
$ICORPEsbServiceStatus,
$ACORPEsbServiceStatus
)
CLS

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$HtmlTemplate = [String]::Format("{0}Notifications\Templates\DailyEnvironmentStatus.html",$Global:ScriptSourcePath)
$HtmTemplate =  [String]::Format("{0}DIA_DailyEnvStatus.htm",$Global:TempNotificationsFolder)
$EnvCheckPropertiesFile=[String]::Format("{0}JenkinsParameterProperties\DailyEnvStatus.Properties",$Global:InputParametersPath)

if(-not (Test-Path $HtmTemplate))
{
New-Item $HtmTemplate -itemtype file
}

$subject="Environment Status: DCORP,ICORP & ACORP"
$Recipients="pankaj.kumarjha@baloise.be"
#,uday.turumella@baloise.be
Write-Host "Environment status for DCORP, ICORP & ACORP - " 

Write-Host "`n==========================Environment :DCORP=========================" `n`r
Write-Host "MWEB URL Status         :"$DCORPMwebURLStatus
Write-Host "CDS URL Status    	    :"$DCORPCdsURLStatus
Write-Host "Backend URL Status	    :"$DCORPBackendURLStatus
Write-Host "CLEVA URL Status  	    :"$DCORPClevaURLStatus
Write-Host "MNET URL Status   	    :"$DCORPClassicURLStatus
Write-Host "NINA URL Status   	    :"$DCORPNinaURLStatus
Write-Host "CDS Services Status     :"$DCORPCdsServiceStatus
Write-Host "Backend Services Status :"$DCORPBackendServiceStatus
Write-Host "ESB Services Status     :"$DCORPEsbServiceStatus
Write-Host "CLEVA Client Status     :"$DCORPClevaClientStatus
Write-Host "Mainframe Check Status  :"$DCORPMFCheckStatus
Write-Host "MNET Services Status    :"$DCORPMnetServiceStatus
Write-Host "SOAPUI Tests Status     :"$DCORPSoapUIStatus

Write-Host "`n==========================Environment :ICORP=========================" `n`r
Write-Host "MNET Services Status    :"$ICORPMnetServiceStatus
Write-Host "MWEB URL Status         :"$ICORPMwebURLStatus
Write-Host "CDS URL Status    	    :"$ICORPCdsURLStatus
Write-Host "Backend URL Status	    :"$ICORPBackendURLStatus
Write-Host "CLEVA URL Status  	    :"$ICORPClevaURLStatus
Write-Host "MNET URL Status   	    :"$ICORPClassicURLStatus
Write-Host "NINA URL Status   	    :"$ICORPNinaURLStatus
Write-Host "CDS Services Status     :"$ICORPCdsServiceStatus
Write-Host "Backend Services Status :"$ICORPBackendServiceStatus
Write-Host "ESB Services Status     :"$ICORPEsbServiceStatus
Write-Host "TALK Client Status      :"$ICORPTalkClientStatus
Write-Host "MNET Client Status      :"$ICORPClassicClientStatus
Write-Host "CLEVA Client Status     :"$ICORPClevaClientStatus
Write-Host "Mainframe Check Status  :"$ICORPMFCheckStatus
Write-Host "SOAPUI Tests Status     :"$ICORPSoapUIStatus
Write-Host "CODEDUI Tests Status    :"$ICORPCodedUITests

Write-Host "`n==========================Environment :ACORP=========================" `n`r
Write-Host "MWEB URL Status   	    :"$ACORPMwebURLStatus
Write-Host "CDS URL Status    	    :"$ACORPCdsURLStatus
Write-Host "Backend URL Status	    :"$ACORPBackendURLStatus
Write-Host "CLEVA URL Status  	    :"$ACORPClevaURLStatus
Write-Host "MNET URL Status   	    :"$ACORPClassicURLStatus
Write-Host "NINA URL Status   	    :"$ACORPNinaURLStatus
Write-Host "CDS Services Status     :"$ACORPCdsServiceStatus
Write-Host "Backend Services Status :"$ACORPBackendServiceStatus
Write-Host "MNET Services Status    :"$ACORPMnetServiceStatus
Write-Host "ESB Services Status     :"$ACORPEsbServiceStatus
Write-Host "TALK Client Status      :"$ACORPTalkClientStatus
Write-Host "MNET Client Status      :"$ACORPClassicClientStatus
Write-Host "CLEVA Client Status     :"$ACORPClevaClientStatus
Write-Host "Mainframe Check Status  :"$ACORPMFCheckStatus
Write-Host "SOAPUI Tests Status     :"$ACORPSoapUIStatus
Write-Host "CODEDUI Tests Status    :"$ACORPCodedUITests

#Declaring variable to populate overall Status of the application
# Mweb URL Status
if(($DCORPMwebURLStatus -ieq "OK") -and ($ICORPMwebURLStatus -ieq "OK") -and ($ACORPMwebURLStatus -ieq "OK"))
{
$MwebURLCheckStatus="OK"
}
else{$MwebURLCheckStatus="NOK"}

# CodedUI Test Status
if(($ICORPCodedUITests -ieq "OK") -or ($ICORPCodedUITests -ieq "PASSED") -or ($ICORPCodedUITests -ieq "UNSTABLE") -or ($ICORPCodedUITests -ieq "Execution Ongoing") -or ($ICORPCodedUITests -ieq "Execution not started") -or  ($ACORPCodedUITests -ieq "OK") -or ($ACORPCodedUITests -ieq "PASSED") -or ($ACORPCodedUITests -ieq "UNSTABLE") -or ($ACORPCodedUITests -ieq "Execution Ongoing") -or ($ACORPCodedUITests -ieq "Execution not started"))
{
$CodedUITestsStatus="OK"
}
Else{$CodedUITestsStatus="NOK"}

# CDS URL Status
if(($DCORPCdsURLStatus -ieq "OK") -and ($ICORPCdsURLStatus -ieq "OK") -and ($ACORPCdsURLStatus -ieq "OK"))
{
$CdsURLCheckStatus="OK"
}else{$CdsURLCheckStatus="NOK"}

# CDS Service Status
if(($DCORPCdsServiceStatus -ieq "OK") -and ($ICORPCdsServiceStatus -ieq "OK") -and ($ACORPCdsServiceStatus -ieq "OK"))
{
$CdsServiceStatus="OK"
}else{$CdsServiceStatus="NOK"}

# Backend URL Status
if(($DCORPBackendURLStatus -ieq "OK") -and ($ICORPBackendURLStatus -ieq "OK") -and ($ACORPBackendURLStatus -ieq "OK"))
{
$BabeURLStatus="OK"
}else{$BabeURLStatus="NOK"}

# Backend Service Status
if(($DCORPBackendServiceStatus -ieq "OK") -and ($ICORPBackendServiceStatus -ieq "OK") -and ($ACORPBackendServiceStatus -ieq "OK"))
{
$BabeServiceStatus="OK"
}else{$BabeServiceStatus="NOK"}

# Cleva URL Status
if(($DCORPClevaURLStatus -ieq "OK") -and ($ICORPClevaURLStatus -ieq "OK") -and ($ACORPClevaURLStatus -ieq "OK"))
{
$ClevaURLStatus="OK"
}else{$ClevaURLStatus="NOK"}

# Cleva Client Status
if(($DCORPClevaClientStatus -ieq "OK") -and ($ICORPClevaClientStatus -ieq "OK") -and ($ACORPClevaClientStatus -ieq "OK"))
{
$ClevaClientStatus="OK"
}else{$ClevaClientStatus="NOK"}

# SOAPUI Tests Status
if(($DCORPSoapUIStatus -ieq "OK") -and ($ICORPSoapUIStatus -ieq "OK") -and  ($ACORPSoapUIStatus -ieq "OK"))
{
$SOAPUITestStatus="OK"
}
else{$SOAPUITestStatus="NOK"}

# NINA URL Status
if(($DCORPNinaURLStatus -ieq "OK") -and ($ICORPNinaURLStatus -ieq "OK") -and ($DCORPNinaURLStatus -ieq "OK"))
{
$NINAUrlStatus="OK"
}else{$NINAUrlStatus="NOK"}

# Mainframe-Check Status
if(($DCORPMFCheckStatus -ieq "OK") -and ($ICORPMFCheckStatus -ieq "OK") -and ($ACORPMFCheckStatus -ieq "OK"))
{
$MFCheckStatus="OK"
}else{$MFCheckStatus="NOK"}

# MNET URL Status
if(($DCORPClassicURLStatus -ieq "OK") -and ($ICORPClassicURLStatus -ieq "OK") -and ($ACORPClassicURLStatus -ieq "OK"))
{
$MNETUrlStatus="OK"
}else{$MNETUrlStatus="NOK"}

# MNET Services Status
if(($DCORPMnetServiceStatus="OK") -and ($ICORPMnetServiceStatus -ieq "OK") -and ($ACORPMnetServiceStatus -ieq "OK"))
{
$MNETServiceStatus="OK"
}else{$MNETServiceStatus="NOK"}

# MNET Client Status
if(($ICORPClassicClientStatus = "OK") -and ($ACORPClassicClientStatus -ieq "OK"))
{
$MNETClientStatus="OK"
}else{$MNETClientStatus="NOK"}

# TALK Client Status
if(($ICORPTalkClientStatus -ieq "OK") -and ($ACORPTalkClientStatus -ieq "OK"))
{
$TALKClilentStatus="OK"
}else{$TALKClilentStatus="NOK"}


# ESB Services Status
if(($DCORPEsbServiceStatus -ieq "OK") -and ($ICORPEsbServiceStatus -ieq "OK") -and ($ACORPEsbServiceStatus -ieq "OK"))
{
$ESBServicesStatus="OK"
}else{$ESBServicesStatus="NOK"}

$HtmlBody = [System.IO.File]::ReadAllLines($HtmlTemplate)

$TableBody = "<TABLE class='rounded-corner'>"
$TableBody += "<tr><th colspan='7'>Environment Status</th></tr>"
$TableBody += "<TR><TH>S.No</TH><th>Applications</th><th>ValidationTests</th><th>DCORP</th><th>ICORP</th><th>ACORP</th><th>Overall Status</th></TR>"

$TableBody += "<tr align='center'><td rowspan='2'><b>1</b></td><td rowspan='2'><b>MyBaloiseWeb</b></td><td>URLs Status</td><td>$DCORPMwebURLStatus</td><td>$ICORPMwebURLStatus</td><td>$ACORPMwebURLStatus</td><td>$MwebURLCheckStatus</td></tr>"
$TableBody += "<tr align='center'><td>CodedUI Smoke Tests</td><td bgcolor='yellow'>N/A</td><td>$ICORPCodedUITests</td><td>$ACORPCodedUITests</td><td>$CodedUITestsStatus</td></tr>"

$TableBody += "<tr align='center'><td rowspan='2'><b>2</b></td><td rowspan='2'><b>CentralDataStore</b></td><td>URLs Status</td><td>$DCORPCdsURLStatus</td><td>$ICORPCdsURLStatus</td><td>$ACORPCdsURLStatus</td><td>$CdsURLCheckStatus</td></tr>"
$TableBody += "<tr align='center'><td>Service Status</td><td>$DCORPCdsServiceStatus</td><td>$ICORPCdsServiceStatus</td><td>$ACORPCdsServiceStatus</td><td>$CdsServiceStatus</td></tr>"

$TableBody += "<tr align='center'><td rowspan='2'><b>3</b></td><td rowspan='2'><b>Backend</b></td><td>URLs Status</td><td>$DCORPBackendURLStatus</td><td>$ICORPBackendURLStatus</td><td>$ACORPBackendURLStatus</td><td>$BabeURLStatus</td></tr>"
$TableBody += "<tr align='center'><td>Services Status</td><td>$DCORPBackendServiceStatus</td><td>$ICORPBackendServiceStatus</td><td>$ACORPBackendServiceStatus</td><td>$BabeServiceStatus</td></tr>"

$TableBody += "<tr align='center'><td rowspan='3'><b>4</b></td><td rowspan='3'><b>CLEVA</b></td><td>URLs Status</td><td>$DCORPClevaURLStatus</td><td>$ICORPClevaURLStatus</td><td>$ACORPClevaURLStatus</td><td>$ClevaURLStatus</td></tr>"
$TableBody += "<tr align='center'><td>Clients Status</td><td>$DCORPClevaClientStatus</td><td>$ICORPClevaClientStatus</td><td>$ACORPClevaClientStatus</td><td>$ClevaClientStatus</td></tr>"
$TableBody += "<tr align='center'><td>SOAPUI Tests</td><td>$DCORPSoapUIStatus</td><td>$ICORPSoapUIStatus</td><td>$ACORPSoapUIStatus</td><td>$SOAPUITestStatus</td></tr>"

$TableBody += "<tr align='center'><td><b>5</b></td><td align='center'><b>NINA</b></td><td>URLs Status</td><td>$DCORPNinaURLStatus</td><td>$ICORPNinaURLStatus</td><td>$ACORPNinaURLStatus</td><td>$NINAUrlStatus</td></tr>"

$TableBody += "<tr align='center'><td><b>6</b></td><td align='center'><b>Mainframe</b></td><td>Mainframe Status</td><td>$DCORPMFCheckStatus</td><td>$ICORPMFCheckStatus</td><td>$ACORPMFCheckStatus</td><td>$MFCheckStatus</td></tr>"

$TableBody += "<tr align='center'><td rowspan='3'><b>7</b></td><td rowspan='3'><b>MyBaloiseClassic</b></td><td>URLs Status</td><td>$DCORPClassicURLStatus</td><td>$ICORPClassicURLStatus</td><td>$ACORPClassicURLStatus</td><td>$MNETUrlStatus</td></tr>"
$TableBody += "<tr align='center'><td>Services Status</td><td>$DCORPMnetServiceStatus</td><td>$DCORPMnetServiceStatus</td><td>$DCORPMnetServiceStatus</td><td>$MNETServiceStatus</td></tr>"
$TableBody += "<tr align='center'><td>Clients Status</td><td bgcolor='yellow'>N/A</td><td>$ICORPClassicClientStatus</td><td>$ACORPClassicClientStatus</td><td>$MNETClientStatus</td></tr>"

$TableBody += "<tr align='center'><td><b>8</b></td><td align='center'><b>TALK</b></td><td>Clients Status</td><td bgcolor='yellow'>N/A</td><td>$ICORPTalkClientStatus</td><td>$ACORPTalkClientStatus</td><td>$TALKClilentStatus</td></tr>"

$TableBody += "<tr align='center'><td><b>9</b></td><td align='center'><b>ESB</b></td><td>Services Status</td><td>$DCORPEsbServiceStatus</td><td>$ICORPEsbServiceStatus</td><td>$ACORPEsbServiceStatus</td><td>$ESBServicesStatus</td></tr>"
$TableBody += "</Table>"

[string]$HtmlBody = $HtmlBody -ireplace "#EnvReport#",$TableBody
$HtmlBody=$HtmlBody -ireplace "<td>NOK</td>","<td bgcolor='red'><font color='White'>NOK</td>" 
$HtmlBody=$HtmlBody -ireplace "<td>Execution Ongoing</td>","<td bgcolor='#F39C12'><font color='White'>Execution Ongoing</td>"
$HtmlBody=$HtmlBody -ireplace "<td>Execution not started</td>","<td bgcolor='#F39C12'><font color='White'>Execution not started</td>"
$HtmlBody=$HtmlBody -ireplace "<td>OK</td>","<td bgcolor='green'><font color='White'>OK</td>"
$HtmlBody=$HtmlBody -replace "<td>FAILED</td>","<td bgcolor='red'><font color='White'>FAILED</td>"
$HtmlBody| Out-File $HtmTemplate

# Sending mail 
SendMail -To $Recipients -body $HtmlBody -subject $subject
