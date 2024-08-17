Param(
[string]$Env,
[string]$MailRecipients
)

#$Env="DCORP"
#$MailRecipients = "Shivajip@baloise.be"
$style=@"
 <STYLE type="text/css">
 body 
 {
 font-family: "verdana, Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
 text-align: left;
 font-size: 12px;
 }
 .rounded-corner
{
	font-family: "verdana, Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
	font-size: 13px;
	margin: 45px;
	width: 480px;
	text-align: center;
	border-collapse: collapse;
	
}
.rounded-corner th
{
	border-right: 1px solid #fff;
	padding: 8px;
	font-weight: bold;
	font-size: 13px;
	color: #039;
	background: #b9c9fe;
	white-space:nowrap;
}
.rounded-corner td
{
	padding: 8px;
	background: #e8edff;
	border-top: 1px solid #fff;
	border-right: 1px solid #fff;
	
}
 </STYLE>
"@
$fcount=0;
$row=""
$Envstatus="SUCCESSFUL"
$globalManifest = '\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\JenkinsParameterProperties\GlobalReleaseManifest.xml'
$xml = [xml](Get-Content $globalManifest)
$Appnodes=$xml.SelectNodes("/Release/environment[@Name='$Env']/Application")
#write-host "/Release/environment[@Name='$Env']/Application"
$date=[DateTime]::Now.ToString("dd-MM-yyyy HH:MM") 
foreach($app in $Appnodes)
{
#Write-Host $app.Name $app.LastReleaseStatus
$Name=$app.Name
$Version=$app.Version
$preVersion=$app.PreviousVersion
$CodeBranch=$app.TFSBranch
$timestamp=$app.LastReleaseDate
$status=$app.LastReleaseStatus
if($status -ne "SUCCESS")
{
$res="<TD style='background:#DC4C4C;color:white;font-weight:bold'>$status</TD>"
$fcount++
$Envstatus="PARTIALLY SUCCEEDED"
}
else
{
$res="<TD style='background:#58dc4c;color:white;font-weight:bold'>$status</TD>"

}
$row+="<TR> 
<TD>$Name</TD> 
<TD>$Version</TD> 
<TD>$preVersion</TD> 
<TD>$CodeBranch</TD> 
<TD>$timestamp</TD> 
$res
</TR>"
}

$strHTMLBody=""
$strHTMLBody=@"
<HTML>
<head>
$style
</head>
<Body>
Dear Colleagues
<BR><BR>
please find the status of <b>$Env</b> build and Deployment as of <b>$date</b>
<BR><BR>
<table class='rounded-corner'>
<TR>
<TH>Application Name</TH>
<TH>Release Version</TH>
<TH>Previous Version</TH>
<TH>TFS Branch</TH>
<TH>Last Deployment DateTime</TH>
<TH>Last Release Status</TH>
</TR>
$row
</table>
<BR><BR>
For more information regarding detailed Build and Deployment information of the above application on $Env, Please click the link Below
<BR><B>
<a href="http://Jenkins-be:8080/view/$Env%20Build%20and%20Deployment%20View/">Jenkins DCORP Build and Install</a>
</b>
<BR><BR>
<i>Regards,</i>
<BR>
<b>ICT Build and Install Team</b><BR>
Baloise-Belgium
</Body>
</HTML>
"@
$strHTMLBody | Out-File -FilePath "D:\Shivaji\MyPS\test.htm"
if($fcount -eq $Appnodes.Count)
{
$Envstatus="FAILED"
}

$now=[DateTime]::Now.ToString("dd-MM-yyyy") 
$smtpServer = "smtp.baloisenet.com"
$smtpFrom = "Jenkins@baloise.be"
$message = New-Object System.Net.Mail.MailMessage $smtpFrom, $MailRecipients
$message.Subject = "$Env Daily Build and Deployment Status : $now - $Envstatus"
$message.IsBodyHTML = $true
$message.Body=$strHTMLBody
#selvaraj.ashokkumar@baloise.be
$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
$smtp.Send($message)
