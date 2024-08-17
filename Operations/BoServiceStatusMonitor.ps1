Param([string]$Environment,[string]$MailRecipients)


#$MailRecipients = "Shivaji.pai@baloise.be"
#$Environment="ICORP"

$BOServerList="E:\BuildTeam\InputInfo\BackOfficeservices\"
$templatePath="E:\BuildTeam\Templates\BoServiceMonitor_Template.html"
$htmlfilepath="E:\BuildTeam\Temp\BoServiceMonitor.html"
$htmlfile=Get-Content $templatePath
$date=[DateTime]::Now.ToString("dd-MM-yyyy HH:MM") 
$servers=Get-ChildItem -Path $BOServerList -Filter "$Environment*.txt" -recurse | % { $_.FullName }

$strenvHTML=$Environment
$strhtml=""
foreach($ser in $servers)
{
$strhtml+="<table class='rounded-corner'>"
$servicelist=Get-Content -Path $ser
$fileinfo=(Split-Path $ser -Leaf) -split "_"
$Env=$fileinfo[0]
$servername = (Split-Path $fileinfo[1] -Leaf) -replace ".txt",""
$strhtml+=[String]::Format("<TR><TH>Environment :{1}</TH><TH>Server : {0}</TH></TR>",$servername,$Env)
$strhtml+= "<TR><TH>Service Name</TH><TH> Status</TH></TR>"
foreach($service in $servicelist)
{
$sc=Get-Service -ComputerName $servername -Name $service
if($sc.Status -match "running"){
$color="#58dc4c"
}
else{
$color="#DC4C4C"
}
$strhtml+=[String]::Format("<TR><TD>{0}</TD><TD bgcolor style='background:{2};color:white;font-weight:bold'>{1}</TD></TR>",$sc.DisplayName,$sc.Status,$color )
}
$strhtml+="</table>"
}
$htmlfile=$htmlfile -replace "#TABLES#",$strhtml
$htmlfile=$htmlfile -replace "#DATETIME#",$date
if($strenvHTML -eq ""){
$strenvHTML="DCORP ICORP, ACORP"
}
$htmlfile=$htmlfile -replace "#ENV#",$strenvHTML
Set-Content $htmlfilepath -Value $htmlfile



$now=[DateTime]::Now.ToString("dd-MM-yyyy") 
$smtpServer = "smtp.baloisenet.com"
$smtpFrom = "Jenkins@baloise.be"
$message = New-Object System.Net.Mail.MailMessage $smtpFrom, $MailRecipients
$message.Subject = "$strenvHTML Back Office Services Status : $now "
$message.IsBodyHTML = $true
$message.Body=$htmlfile
$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
$smtp.Send($message)





