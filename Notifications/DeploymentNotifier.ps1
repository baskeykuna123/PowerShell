Param($Environment,$ApplicationName,$Stage,$buildNumber)
#$Environment="DCORP"
#$ApplicationName="MyBaloiseWeb"
#$Stage="Completed"
#$DBRecipientParameterName="DailyDeploymentMailReceivers"
clear

$emaillistfile="\\shw-me-pdnet01\BuildTeam\Temp\EmailParameters.txt"
$paramfile=@{}
foreach($line in [System.IO.File]::ReadAllLines($emaillistfile)){
$paramfile+= ConvertFrom-StringData $line
}
$strHTMLBody=Get-Content -Path "\\shw-me-pdnet01\BuildTeam\Templates\DeploymentMailer_Template.html"
$globalManifest = '\\shw-me-pdnet01\Repository\GlobalReleaseManifest.xml'
$xml = [xml](Get-Content $globalManifest )
#Get the application no to be updateed
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='$ApplicationName']")
$MwebBaseversion=$node.Version.Split('.')[0] + '.' +$node.Version.Split('.')[1]
$Version=$node.Version
# DB server information
$DBuserid="L001171"
$DBpassword="teCH_Key_PRO"
$dbserver="sql-be-buildp"
$dbName=[string]::Format("MercatorBuild.{0}",$node.ParentNode.MercatorBuildVersion)
$selectQuery="SELECT [ParameterValue] FROM dbo.CommonParameters where ParameterName ='$DBRecipientParameterName'"
#$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
$MailRecipients=$null
$MailRecipients=$paramfile["DailyDeploymentMailReceivers"]
#$MailRecipients='shivaji.pai@baloise.be'
foreach($id in $MailRecipients.Split(',')){
if($id -notlike "*@*"){
$updated=$id+"@baloise.be"
$MailRecipients=$MailRecipients -replace $id,$updated
}
}

$MailRecipients=$MailRecipients.Split(',')
$color="#33cc33"
if($Stage -match "Started"){
$color="#ffcc00"
}
$stageval=[string]::Format("<td style='background:{0}'><b>$stage</b></td>",$color)
$table=@"
<TABLE class='rounded-corner'>
<tr><th>Application Name</th><th>Deployment Status</th></tr>
<tr><td>MyBaloiseWeb Broker</td>$stageval</tr>
<tr><td>MyBaloiseWeb Internal</td>$stageval</tr>
<tr><td>MyBaloiseWeb Public</td>$stageval</tr>
</TABLE>
"@

#[string[]]$MailRecipients=$select.ParameterValue
Write-Host Mail Recievers list :$MailRecipients
$strHTMLBody=$strHTMLBody -replace "#TABLES#",$table
$strHTMLBody=$strHTMLBody -replace "#APPNAME#",$ApplicationName
$strHTMLBody=$strHTMLBody -replace "#ENV#",$Environment
$strHTMLBody=[string]$strHTMLBody
$smtpServer = "smtp.baloisenet.com"
$smtpFrom = "Jenkins@baloise.be"
$subject="$ApplicationName $Environment $buildNumber Deployment : $Stage"
Send-MailMessage -To $MailRecipients -From $smtpFrom -Subject $subject -Body $strHTMLBody -BodyAsHtml -SmtpServer $smtpServer
