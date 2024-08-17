PARAM(
		$Environments
	 )
	 
#Loading Function
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if(!$Environments){
	$Environments=$global:EnvironmentList
}

	Clear-host
	#$CICSParentFolder = [String]::Format("E:\BuildTeam\Pankaj\TestMainframe\{0}\",$Environment)
	$Curentstatus=@{}
	$MainframeInfo = "<TABLE class='Rounded-Corner'>"
	$MainframeInfo += "<TR align=center><TH colspan='2'>Mainframe Info</TH></TR>"
	foreach($Environment in $Environments.split(',')){
		$CICSParentFolder = "\\balgroupit.com\appl_data\BBE\App01\$Environment\MF\scheduler\IN"
		$CICSFile = gci Filesystem::$CICSParentFolder -Filter "CICS*" -Recurse|?{!$_.PSIsContainer}
		$status=([system.IO.path]::GetFileNameWithoutExtension($CICSFile.Name)).split("-")[1]
#		setproperties -Filepath $CICSCurrentStatusfile -properties $Curentstatus
		Switch($status)
		{
				"ON"{$Action="unreserve"}
				"OFF"{$Action="reserve"}
		}
		$Username = "L002867"
		$Password = "Jenk1ns@B@loise"	
		$Headers = @{ "Authorization" = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password))) }
		$Uri = [String]::Format("http://Jenkins-be:8080/lockable-resources/{0}?resource=MainframeCICS_Watcher",$Action)
		Invoke-RestMethod -Uri $Uri -Headers $Headers -Verbose | Out-Null
		$MainframeInfo += "<TR align=center><TD align=center>$Environment Status</TD><TD>$status</TD></TR>"
		$Uri = [String]::Format("http://Jenkins-be:8080/lockable-resources/{0}?resource=MF_TestEnabled",$Action)
		Invoke-RestMethod -Uri $Uri -Headers $Headers -Verbose | Out-Null
		}
	$MainframeInfo += "</TABLE>"
	$Subject = "CICS-Mainframe Status "
	$HtmTemplate=[String]::Format("{0}\{1}_CICSReport_Template.htm",$global:TempNotificationsFolder,$Environment)
	$BodyHTML = [system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\CICS_Template.html" ))
	$BodyHTML = $BodyHTML -ireplace "#CICSInfo#",$MainframeInfo
	$BodyHTML | Out-File FileSystem::$HtmTemplate
	SendMail -To $global:MainframeWatcherMailingList -body $BodyHTML -subject $Subject