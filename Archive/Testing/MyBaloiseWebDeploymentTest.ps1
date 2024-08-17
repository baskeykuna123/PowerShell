param($Environment,$ApplicationName,$BuildNumber,$DeploymentViewName)

Clear-Host
."\\balgroupit.com\Appl_Data\BBE\Transfer\Packages\Scripts\FnUtilities.ps1"

if(!$BuildNumber){
	$ApplicationName = "NINA"
	$BuildNumber = "DEV_NINA_20170912.2"
	$Environment = "DCORP"
	$DeploymentViewName = "NINA_DCORP_Deployments/"
}


$JenkinsUrl = [string]::Format("http://Jenkins-be:8080/view/{0}/",$DeploymentViewName)
$HtmlBody = [System.IO.File]::ReadAllLines("\\shw-me-pdnet01\BuildTeam\Templates\DeploymentComplete.html")
$temphtmlfile = [string]::Format("\\shw-me-pdnet01\buildteam\temp\Timestamp\{0}_{1}_{2}.htm",$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$ApplicationName)

$DeployParmetersFile=[string]::Format("\\svw-me-pdtalk01\Packages\{0}_{1}\{2}\{3}DeploymentParameters_Resolved.xml",$BuildNumber.Split('_')[0],$BuildNumber.Split('_')[1],$BuildNumber.Split('_')[2],$ApplicationName)
$xml = [xml](Get-Content FileSystem::$DeployParmetersFile )
$node=$xml.SelectSingleNode("//add[@key='MailNotificationRecipients']")

#Validating the URLS
$testoutput = TestURLs -Environment $Environment -ApplicationName $ApplicationName

$Deploymentinfo = "<TR><TD><B>Deployment Version</B></TD><TD>$BuildNumber</TD></TR>"
$Deploymentinfo += "<TR><TD><B>Deployment Log</B></TD><TD><a href=$JenkinsUrl>$ApplicationName Deployment</a></TD></TR>"

$HtmlBody = $HtmlBody -ireplace "#DEPLOYMENTINFO#",$Deploymentinfo
$HtmlBody = $HtmlBody -ireplace "#TESTINFO#",$testoutput
$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
$HtmlBody | Out-File Filesystem::$temphtmlfile
$Mailsubject = "$ApplicationName $Environment Deployment : $BuildNumber - Completed"
SendMail -To $node.value -subject $Mailsubject -body $HtmlBody
Remove-Item FileSystem::$temphtmlfile
