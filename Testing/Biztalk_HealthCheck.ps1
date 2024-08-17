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
    $hostInstances = Get-WmiObject MSBTS_HostInstance -namespace root\MicrosoftBizTalkServer -ErrorAction Stop
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

$Biztalkinfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='2'><B>BizTalk Information</B></TH></TR>
<TR align=center ><TH><B>Host Instance</B></TH><TH><B>Type</B></TH><TH><B>State</B></TH></TR>
"@


# Display BizTalk Information
$Biztalkinfo+="<TR><TD><B>$($BiztalkREG.ProductName)</B></TD><TD>$($BiztalkREG.ProductEdition)</TD></TR>"
$Biztalkinfo+="<TR><TD><B>Product Version</B></TD><TD>$($BiztalkREG.ProductVersion)</TD></TR>"
$Biztalkinfo+="<TR><TD><B>Server Name</B></TD><TD>$($BiztalkServer.Name)</TD></TR>"
$Biztalkinfo+="<TR><TD><B>BizTalk Admin group</B></TD><TD>$($BizTalkGroup.BizTalkAdministratorGroup)</TD></TR>"
$Biztalkinfo+="<TR><TD><B>BizTalk Operators group</B></TD><TD>$($BizTalkGroup.BizTalkOperatorGroup)</TD></TR>"

$Biztalkinfo="</TABLE>"


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
		$bgcolor="green"
    }
    elseif ($application.Status -eq "Stopped") {
        Write-Host $application.Name "- " -NoNewline
        Write-Host $application.Status -fore Red
		$bgcolor="red"
    }
    else {
        Write-Host $application.Name "- " -NoNewline
        Write-Host $application.Status -fore DarkYellow
		$bgcolor="yellow"
    }
	$Appinfo+="<TR><TD><B>$($application.Name)</B></TD><TD bgcolor='$bgcolor'>$($application.Status)</TD></TR>"
}
$Appinfo+="</Table>"




# Get and Display BizTalk Receive Location Information
[ARRAY]$recLocs = get-wmiobject MSBTS_ReceiveLocation -namespace 'root\MicrosoftBizTalkServer' | Where-Object {$_.IsDisabled -eq "true" }
Write-Host "`nDisabled Receive Locations (" $recLocs.Count ")" -fore DarkGray

# Get and Display BizTalk Send Port Information
[ARRAY]$sendPorts = get-wmiobject MSBTS_SendPort -namespace 'root\MicrosoftBizTalkServer' | Where-Object {$_.Status -eq 2 -or $_.Status -eq 1}
Write-Host "`nStopped and Unenlisted Send Ports (" $sendPorts.Count ")" -fore DarkGray

# Get and Display Orchstrations not started
[ARRAY]$orchs = Get-WmiObject MSBTS_Orchestration -namespace 'root\MicrosoftBizTalkServer' | Where-Object {$_.OrchestrationStatus -ne 4 }
Write-Host "`nNot Started Orchestrations (" $orchs.Count ")" -fore DarkGray

$RecieveLocationinfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH><B>Disabled Receive Locations($($recLocs.Count))</B></TH></TR>
"@
if ($recLocs.Count -gt 0) { 
	$recLocs | Foreach {
		$RecieveLocationinfo+="<TR align=center ><TD><B>$($_.Name)</B></TD></TR>"
	}
}
else { Write-Host "None" }
$RecieveLocationinfo+="</TABLE>"


$SendPortInfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='2'><B>Stopped and Unenlisted Send Ports($($sendPorts.Count))</B></TH></TR>
<TR align=center ><TH><B>Name</B></TH><TH><B>Send Pipeline</B></TH></TR>
"@

if ($sendPorts.Count -gt 0) { 
$sendPorts | Foreach {
$SendPortInfo+="<TR><TD><B>$($_.Name)</B></TD><TD>$($_.SendPipeline)</TD></TR>"
}
}
else { Write-Host "None" }
$SendPortInfo+="</TABLE>"

$OrchInfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='2'><B>Stopped and Unenlisted Send Ports($($orchs.Count))</B></TH></TR>
<TR align=center ><TH><B>Name</B></TH><TH><B>path</B></TH></TR>
"@

$orchs |Ft Name,__PATH
if ($orchs.Count -gt 0) { 
	$orchs | Foreach { 
		$OrchInfo+="<TR><TD><B>$($_.Name)</B></TD><TD>$($_.__PATH)</TD></TR>"
	}
}
else { Write-Host "None" }
$OrchInfo+="</TABLE>"

#Display IIS information
$IISInfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='3'><B>IIS Info</B></TH></TR>
<TR align=center ><TH><B>Application pool</B></TH><TH><B>State</B></TH><TH><B>Applications</B></TH></TR>
"@

try {
    Import-Module WebAdministration
    Write-Host "IIS Version:" (get-itemproperty HKLM:\SOFTWARE\Microsoft\InetStp\).setupstring
    Write-Host "`nApplication Pools" -Fore DarkGray -NoNewLine
    Get-ChildItem IIS:\apppools | ft -AutoSiz
	Get-ChildItem IIS:\apppools | foreach {
	$_.Applications
		$IISInfo+="<TR><TD><B>$($_.Name)</B></TD><TD>$($_.State)</TD><TD>$($_.Applications)</TD></TR>"
	}
	
}
catch {
    Write-Host "Unable to perform IIS checks" -fore Red
}
$IISInfo+="</TABLE>"



$MailTemplate=[system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\BIZTALK_StatusCheck.html" ))
$temphtmlfile = [string]::Format("{0}\{1}_URLTest_{2}_{3}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$ApplicationName)

$MailTemplate = $MailTemplate -ireplace "#SERVERINFO#",$Biztalkinfo
$MailTemplate = $MailTemplate -ireplace "#SERVICEINFO#",$HostInstanceStateinfo
$MailTemplate = $MailTemplate -ireplace "#APPLICATIONINFO#",$Appinfo
$MailTemplate = $MailTemplate -ireplace "#RECIEVEINFO#",$RecieveLocationinfo
$MailTemplate = $MailTemplate -ireplace "#SENDINFO#",$SendPortInfo
$MailTemplate = $MailTemplate -ireplace "#ORCHINFO#",$OrchInfo
$MailTemplate = $MailTemplate -ireplace "#IISINFO#",$IISInfo
$MailTemplate = $MailTemplate -ireplace "#ENV#",$Environment
$MailTemplate | Out-File Filesystem::$temphtmlfile
$Mailsubject = "$Environment ESB Health Check"
SendMail -To $MailRecipients -subject $Mailsubject -body $MailTemplate
#Remove-Item FileSystem::$temphtmlfile

$endTime = Get-Date
Write-Host "`nScript processing time:" ([Math]::Round($(($endTime-$startTime).TotalMinutes), 2)) "minutes"

