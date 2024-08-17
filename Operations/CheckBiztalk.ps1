PARAM($Environment,$MailRecipients)

Clear-Host

#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


if(!$Environment){
$MailRecipients="Shivaji.pai@baloise.be"
$Environment="DCORP"
}


$startTime = Get-Date
Write-Host "Health Check Start Date/Time:" $startTime
$MailBodyHtml=""
$MailTemplate=get-content "\\shw-me-pdnet01\BuildTeam\Templates\ESBHealthPage.html"
try { # Get BizTalk Information
    $BizTalkGroup = Get-WmiObject MSBTS_GroupSetting -namespace root\MicrosoftBizTalkServer -ErrorAction Stop
    $BizTalkMsgBoxDb = Get-WmiObject MSBTS_MsgBoxSetting -namespace root\MicrosoftBizTalkServer -ErrorAction Stop
    $BizTalkServer = Get-WmiObject MSBTS_Server -namespace root\MicrosoftBizTalkServer -ErrorAction Stop
    $BizTalkREG = Get-ItemProperty "hklm:\SOFTWARE\Microsoft\BizTalk Server\3.0" -ErrorAction Stop
    $trackingHost = Get-WmiObject MSBTS_Host -Namespace root\MicrosoftBizTalkServer -ErrorAction Stop | where {$_.HostTracking -eq "true" }
    [void] [System.reflection.Assembly]::LoadWithPartialName("Microsoft.BizTalk.ExplorerOM")
    $BizTalkDBInstance = $BizTalkGroup.MgmtDbServerName
    $BizTalkDB = $BizTalkGroup.MgmtDbName
    $BizTalkOM = New-Object Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer
    $BizTalkOM.ConnectionString = "SERVER=$BizTalkDBInstance;DATABASE=$BizTalkDB;Integrated Security=SSPI"
}
catch {
    Write-Host "BizTalk not detected on this machine, or user not member of BizTalk Administrators group" -fore Red
    exit
}

# Biztalk artifacts Summary report

# Host Instances
$hostInstances = Get-WmiObject MSBTS_HostInstance -namespace root\MicrosoftBizTalkServer -ErrorAction Stop
$StartedHostInstanceCount=$hostInstances|?{$_.Servicestate -eq '4'}
$StoppedHostInstanceCount=$hostInstances|?{$_.Servicestate -eq '1'}
$UnknownHostInstanceCount=$hostInstances|?{$_.Servicestate -eq '8'}
$ArtifactsSummary = @"
<TABLE class='rounded-corner'>
<TR align=center><TH colspan='2'><B>HostInstances Summary</B></TH></TR>
<TR align=center><TD align=left><B>Running Instances</B></TD><TD>$($StartedHostInstanceCount.HostName.count)</TD></TR>
<TR align=center><TD align=left><B>Stopped Instances</B></TD><TD>$($StoppedHostInstanceCount.HostName.count)</TD></TR>
<TR align=center><TD align=left><B>Unknown Instances</B></TD><TD>$($UnknownHostInstanceCount.HostName.count)</TD></TR>
<TR align=center><TD><B>TOTAL INSTANCES</B></TD><TD>$($hostInstances.HostName.count)</TD></TR>
"@

# Biztalk Applications
$applications = $BizTalkOM.Applications
$StartedApplications=$applications|?{$_.Status -ieq "Started"}
$StoppedApplications=$applications|?{$_.Status -ieq "Stopped"}
$PartiallyStartedApplications=$applications|?{$_.Status -ieq "PartiallyStarted"}
$UnknownApplications=$applications|?{$_.Status -ieq "NotApplicable"}
$ArtifactsSummary += @"
<TR align=center><TH colspan='2'><B>BizTalk Applications Summary</B></TH></TR>
<TR align=center><TD align=left><B>Started Applications</B><TD>$($StartedApplications.count)</TD></TR>
<TR align=center><TD align=left><B>Partially Started Applications</B><TD>$($PartiallyStartedApplications.count)</TD></TR>
<TR align=center><TD align=left><B>Stopped Applications</B><TD>$($StoppedApplications.count)</TD></TR>
<TR align=center><TD align=left><B>Unknown Applications</B><TD>$($UnknownApplications.count)</TD></TR>
<TR align=center><TD><B>TOTAL APPLICATIONS</B><TD>$($applications.count)</TD></TR>
"@

# Receive Locations
[ARRAY]$recLocs = get-wmiobject MSBTS_ReceiveLocation -namespace 'root\MicrosoftBizTalkServer'
$TotalEnabledReceiveLocation=$recLocs|?{$_.IsDisabled -imatch "False"}
$TotalDisabledReceiveLocation=$recLocs|?{$_.IsDisabled -imatch "True"}
$ArtifactsSummary += @"
<TR align=center><TH colspan='2'><B>ReceiveLocation Summary</B></TH></TR>
<TR align=center><TD align=left><B>Enabled Receive Locations</B><TD>$($TotalEnabledReceiveLocation.count)</TD></TR>
<TR align=center><TD align=left><B>Disabled Receive Locations</B><TD>$($TotalDisabledReceiveLocation.count)</TD></TR>
<TR align=center><TD><B>TOTAL RECEIVE LOCATIONS</B><TD>$($recLocs.count)</TD></TR>
"@

# Send Ports
[ARRAY]$sendPorts = get-wmiobject MSBTS_SendPort -namespace 'root\MicrosoftBizTalkServer'
$TotalStartedSendPorts=$sendPorts|?{$_.Status -eq '3'}
$TotalStoppedSendPorts=$sendPorts|?{$_.Status -eq '2'}
$TotalUnenlistedSendPorts=$sendPorts|?{$_.Status -eq '1'}
$ArtifactsSummary += @"
<TR align=center><TH colspan='2'><B>SendPort Summary</B></TH></TR>
<TR align=center><TD align=left><B>Started SendPorts</B><TD>$($TotalStartedSendPorts.count)</TD></TR>
<TR align=center><TD align=left><B>Stopped SendPorts</B><TD>$($TotalStoppedSendPorts.count)</TD></TR>
<TR align=center><TD align=left><B>unenlisted SendPorts</B><TD>$($TotalUnenlistedSendPorts.count)</TD></TR>
<TR align=center><TD><B>TOTAL SENDPORTS</B><TD>$($sendPorts.count)</TD></TR>
"@


# Orchestrations
[ARRAY]$orchs = Get-WmiObject MSBTS_Orchestration -namespace 'root\MicrosoftBizTalkServer' 
$TotalActiveOrchestration=$orchs|?{$_.OrchestrationStatus -ieq '4'}
$TotalStoppedOrchestration=$orchs|?{$_.OrchestrationStatus -ieq '3'}
$TotalunenlistedOrchestration=$orchs|?{$_.OrchestrationStatus -ieq '2'}
$ArtifactsSummary += @"
<TR align=center><TH colspan='2'><B>Orchestrations Summary</B></TH></TR>
<TR align=center><TD align=left><B>Active Orchestrations</B><TD>$($TotalActiveOrchestration.hostname.count)</TD></TR>
<TR align=center><TD align=left><B>Stopped Orchestrations</B><TD>$($TotalStoppedOrchestration.hostname.count)</TD></TR>
<TR align=center><TD><B>TOTAL ORCHESTRATIONS</B><TD>$($Orchs.hostname.count)</TD></TR>
"@

# IIS ApPools 
Import-Module WebAdministration
$IISInfo=Get-ChildItem IIS:\apppools
$TotalRunningApppools=$IISInfo | ?{$_.State -ieq "Started"}
$TotalStoppedApppools=$IISInfo | ?{$_.State -ieq "Stopped"}
$ArtifactsSummary += @"
<TR align=center><TH colspan='2'><B>IIS AppPool Summary</B></TH></TR>
<TR align=center><TD align=left><B>Running AppPools</B><TD>$($TotalRunningApppools.count)</TD></TR>
<TR align=center><TD align=left><B>Stopped AppPools</B><TD>$($TotalStoppedApppools.count)</TD></TR>
<TR align=center><TD><B>TOTAL APPPOOLS</B><TD>$($IISInfo.count)</TD></TR>
"@

# Services
$servicesList=Get-WmiObject "Win32_Service" |?{$_.StartName -ilike "*L0*"}
$TotalRunningServices=$servicesList|?{$_.State -ieq "Running"}
$TotalStoppedServices=$servicesList|?{$_.State -ieq "Stopped"}
$ArtifactsSummary += @"
<TR align=center><TH colspan='2'><B>Custom Services Summary</B></TH></TR>
<TR align=center><TD align=left><B>Running Services</B><TD>$($TotalRunningServices.count)</TD></TR>
<TR align=center><TD align=left><B>Stopped Services</B><TD>$($TotalStoppedServices.count)</TD></TR>
<TR align=center><TD><B>TOTAL SERVICES</B><TD>$($servicesList.count)</TD></TR>
</TABLE>
"@


$Biztalkinfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='2'><B>BizTalk Information</B></TH></TR>
"@


# Display BizTalk Information
$Biztalkinfo+="<TR><TD><B>$($BiztalkREG.ProductName)</B></TD><TD>$($BiztalkREG.ProductEdition)</TD></TR>"
$Biztalkinfo+="<TR><TD><B>Product Version</B></TD><TD>$($BiztalkREG.ProductVersion)</TD></TR>"
$Biztalkinfo+="<TR><TD><B>Server Name</B></TD><TD>$($BiztalkServer.Name)</TD></TR>"
$Biztalkinfo+="<TR><TD><B>BizTalk Admin group</B></TD><TD>$($BizTalkGroup.BizTalkAdministratorGroup)</TD></TR>"
$Biztalkinfo+="<TR><TD><B>BizTalk Operators group</B></TD><TD>$($BizTalkGroup.BizTalkOperatorGroup)</TD></TR>"

$Biztalkinfo+="</TABLE>"


Write-Host "`nInstalled BizTalk Software" -Fore DarkGray
Get-WmiObject win32_product | where-object { $_.Name -like "*BizTalk*" } | select-object Name -Unique | Sort-Object Name | select -expand Name

# Display BizTalk Host Instance Information
Write-Host "`nHost Instance Information ("$hostInstances.Count")" -fore DarkGray

$HostInstanceStateinfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='3'><B>Host Instances</B></TH></TR>
<TR align=center ><TH><B>Host Instance</B></TH><TH><B>Type</B></TH><TH><B>State</B></TH></TR>
"@

foreach ($hostInstance in $hostInstances) {
    switch ($hostInstance.servicestate) {
        1 { $hostInstanceState = "Stopped" }
        2 { $hostInstanceState = "Start pending" }
        3 { $hostInstanceState = "Stop pending" }
        4 { $hostInstanceState = "Running" }
        5 { $hostInstanceState = "Continue pending" }
        6 { $hostInstanceState = "Pause pending" }
        7 { $hostInstanceState = "Paused" }
        8 { $hostInstanceState = "Unknown" }
    }
    switch ($hostInstance.HostType) {
        1 { $hostInstanceType = "In-process" }
        2 { $hostInstanceType = "Isolated" }
    }
    if ($hostInstanceState -eq "Running") {
        Write-Host $hostInstance.hostname "($hostInstanceType)" "- "  -NoNewline
        Write-Host $hostInstanceState -fore green
		
    }
    elseif ($hostInstanceState -eq "Stopped") {
            if ($hostInstance.IsDisabled -eq $true ) {
                Write-Host $hostInstance.hostname "($hostInstanceType)" "- " -NoNewline
                Write-Host $hostInstanceState "(Disabled)" -fore red
            }
            else {
                Write-Host $hostInstance.hostname "($hostInstanceType)" "- " -NoNewline
                Write-Host $hostInstanceState -fore Red
            }
    }
    else {
        if ($hostInstanceType -eq "In-process") {
            Write-Host $hostInstance.hostname "($hostInstanceType)" "- " -NoNewline
            Write-Host $hostInstanceState "(Disabled:$($hostInstance.IsDisabled))" -fore DarkYellow
        }
        else {
            Write-Host $hostInstance.hostname "($hostInstanceType)"
        }
    }
	
$HostInstanceStateinfo+="<TR><TD><B>$($hostInstance.hostname)</B></TD><TD>$hostInstanceType</TD><TD>$hostInstanceState</TD></TR>"
}
$HostInstanceStateinfo+="</TABLE>"


Write-Host "`nTracking Host(s)" -Fore DarkGray
$trackingHost.Name

# Get BizTalk Application Information
$applications = $BizTalkOM.Applications

# Display BizTalk Application Information
Write-Host "`nBizTalk Applications ("$applications.Count")" -fore DarkGray
$MailBodyHtml+="<BR><BR>"

$Appinfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='2'><B>Biztalk Application Status($($applications.Count))</B></TH></TR>
<TR align=center ><TH><B>Applicaiton</B></TH><TH><B>State</B></TH></TR>
"@
Foreach ($application in $applications) {
    if ($application.Status -eq "Started") {
        Write-Host $application.Name "- " -NoNewline
        Write-Host $application.Status -fore Green
    }
    elseif ($application.Status -eq "Stopped") {
        Write-Host $application.Name "- " -NoNewline
        Write-Host $application.Status -fore Red
    }
    else {
        Write-Host $application.Name "- " -NoNewline
        Write-Host $application.Status -fore DarkYellow
    }
	$Appinfo+="<TR><TD><B>$($application.Name)</B></TD><TD>$($application.Status)</TD></TR>"
}
$Appinfo+="</Table>"


# Get and Display BizTalk Receive Location Information
$ReceiveLocationinfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='3'><B>Biztalk ReceiveLocations Info</B></TH></TR>
<TR align=center ><TH><B>Receive Location Name</B><TH><B>HostName</B></TH></TH><TH><B>Status</B></TH></TR>
"@

[ARRAY]$recLocs = get-wmiobject MSBTS_ReceiveLocation -namespace 'root\MicrosoftBizTalkServer'
ForEach($location in $recLocs){

    Switch($($location.IsDisabled))
    {
        "False"{$status="Enabled"}
        "True" {$Status="Disabled"}
    }
$ReceiveLocationinfo+="<TR><TD><B>$($location.Name)</B></TD><TD>$($location.hostname)</TD><TD>$($Status)</TD></TR>"

}
$ReceiveLocationinfo+="</Table>"

$SendPortinfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='2'><B>Biztalk SendPort Status</B></TH></TR>
<TR align=center ><TH><B>SendPort Name</B></TH><TH><B>Status</B></TH></TR>
"@

# Get and Display BizTalk Send Port Information
[ARRAY]$sendPorts = get-wmiobject MSBTS_SendPort -namespace 'root\MicrosoftBizTalkServer'
Write-Host "`nStopped and Unenlisted Send Ports (" $sendPorts.Count ")" -fore DarkGray
$sendPorts |FT -Property Name,SendPipeline
Write-Host "========================================"
ForEach($SendPort in $sendPorts)
{

	$SendPortStatus=$($SendPort.Status)
	Switch($SendPortStatus)
	{
	3 { $Status="Started"}
	2 { $Status="Stopped"}
	1 { $Status="Unenlisted"}
	}
	Write-Host "`n"
	Write-Host "Send Port Name  :" $($SendPort.Name)
	Write-Host "Send Port Status:" $Status
	Write-Host ""
	$SendPortinfo+="<TR><TD><B>$($SendPort.Name)</B></TD><TD>$($Status)</TD></TR>"
}
Write-Host "========================================"

$SendPortinfo+="</Table>"

if ($sendPorts.Count -gt 0) { $sendPorts.Name }
else { Write-Host "None" }

# Get and Display Orchstrations not started
[ARRAY]$orchs = Get-WmiObject MSBTS_Orchestration -namespace 'root\MicrosoftBizTalkServer' 

$OrchestrationInfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='3'><B>Biztalk Orchestration Info</B></TH></TR>
<TR align=center ><TH><B>Orchestration Name</B></TH><TH><B>HostName</B></TH><TH><B>Status</B></TH></TR>
"@
ForEach($Orch in $Orchs)
{
	$OrchStatus=$($Orch.OrchestrationStatus)
	Switch($OrchStatus)
	{
	4 {$Status = "Started"}
	3 {$Status = "Stopped"}
	2 {$Status = "Unenlisted"}
	}
	$OrchestrationInfo+="<TR><TD><B>$($Orch.Name)</B></TD><TD>$($Orch.hostname)</TD><TD>$($Status)</TD></TR>"
}
$OrchestrationInfo+="</Table>"


# Tracking
Write-Host "`nTracking" -fore DarkGray
[ARRAY]$trackingSendPorts = get-wmiobject MSBTS_SendPort -namespace 'root\MicrosoftBizTalkServer' | Where-Object {$_.Tracking -gt 0 }
[ARRAY]$trackingRecPorts = get-wmiobject MSBTS_ReceivePort -namespace 'root\MicrosoftBizTalkServer' | Where-Object {$_.Tracking -gt 0 }
Write-Host "Receive Ports with Tracking:" $trackingRecPorts.Count
Write-Host "Send Ports with Tracking:" $trackingSendPorts.Count

## Get and Display Windows Information
Write-Host "`nWindows Information" -fore Green
$windowsDetails = Get-WmiObject -Class Win32_OperatingSystem
Write-Host $windowsDetails.Caption
Write-Host "Product Version:" $windowsDetails.Version
Write-Host "Service Pack Level:" $windowsDetails.CSDVersion

#Display IIS information
try {
	
    Import-Module WebAdministration
    Write-Host "IIS Version:" (get-itemproperty HKLM:\SOFTWARE\Microsoft\InetStp\).setupstring
    Write-Host "`nApplication Pools" -Fore DarkGray -NoNewLine
    $IISInfo=Get-ChildItem IIS:\apppools
	
	$IISAppPoolinfo=@"
	<TABLE class='rounded-corner'>
	<TR align=center ><TH colspan='2'><B>Biztalk IIS AppPool Status</B></TH></TR>
	<TR align=center ><TH><B>Application pool Name</B></TH><TH><B>Status</B></TH></TR>
"@
	ForEach($info in $IISInfo)
	{
		$IISAppPoolinfo+="<TR><TD><B>$($info.Name)</B></TD><TD>$($info.State)</TD></TR>"
	}
	$IISAppPoolinfo+="</Table>"
}
catch {
    Write-Host "Unable to perform IIS checks" -fore Red
}

# Check Windows Service state
function FuncCheckService{
     param($ServiceName)
         $arrService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue 
         if ($arrService.Status -eq "Running"){ 
            Write-Host $ServiceName "is running"
            $script:unnecessaryServices++
         }
}

# Service Info
$ServiceInfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='2'><B>Service Info</B></TH></TR>
<TR align=center ><TH><B>Service Name</B></TH><TH><B>Status</B></TH></TR>
"@
$servicesList=Get-WmiObject "Win32_Service" |?{$_.StartName -ilike "*L0*"}
ForEach($Service in $servicesList)
{
	$ServiceInfo+="<TR><TD><B>$($Service.Name)</B></TD><TD>$($Service.State)</TD></TR>"
}
$ServiceInfo += "</Table>"


# Get and Display Computer Information
Write-Host "Computer Information" -fore Green
$computerDetails = Get-WmiObject Win32_ComputerSystem
$drive = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter = 'C:'"
Write-Host "File System (C:):" $drive.FileSystem
Write-Host "Capacity (C:):" ([Math]::Round(($drive.Capacity / 1024 / 1024 / 1024),0)) "GB"
Write-Host "System Type:" $computerDetails.SystemType
Write-Host "Physical RAM:" ([math]::round(($computerDetails.TotalPhysicalMemory/1GB),0))"GB"
Write-Host "Domain:" $computerDetails.Domain
Write-Host "Computer Model:" $computerDetails.model
Write-Host "Computer Manufacturer:" $computerDetails.manufacturer


$HtmlBody=[system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\URLTest_Environment.html" ))
$temphtmlfile = [string]::Format("{0}\{1}_URLTest_{2}_{3}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$ApplicationName)

$MailTemplate = $MailTemplate -ireplace "#SUMMARY#",$ArtifactsSummary
$MailTemplate = $MailTemplate -ireplace "#SERVERINFO#",$Biztalkinfo
$MailTemplate = $MailTemplate -ireplace "#HOSTINSTANCEINFO#",$HostInstanceStateinfo
$MailTemplate = $MailTemplate -ireplace "#APPLICATIONINFO#",$Appinfo
$MailTemplate = $MailTemplate -ireplace "#SENDPORTINFO#",$SendPortinfo
$MailTemplate = $MailTemplate -ireplace "#IISINFO#",$IISAppPoolinfo
$MailTemplate = $MailTemplate -ireplace "#SERVICEINFO#",$ServiceInfo
$MailTemplate = $MailTemplate -ireplace "#ORCHINFO#",$OrchestrationInfo
$MailTemplate = $MailTemplate -ireplace "#RECEIVELOCATIONINFO#",$ReceiveLocationinfo
$MailTemplate = $MailTemplate -ireplace "#ENV#",$Environment
$MailTemplate | Out-File Filesystem::$temphtmlfile
$Mailsubject = "$Environment ESB Health Check"
SendMail -To $MailRecipients -subject $Mailsubject -body $MailTemplate
#Remove-Item FileSystem::$temphtmlfile

#$MailTemplate=
$endTime = Get-Date
Write-Host "`nScript processing time:" ([Math]::Round($(($endTime-$startTime).TotalMinutes), 2)) "minutes"