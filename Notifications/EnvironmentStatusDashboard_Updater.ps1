param($Environment,$ApplicationName,$BuildNumber,$NotificationType,$PlannedTime)
Clear-Host

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$BIDasboardLocation="\\DWEBFM01\e$\Baloise\WebApplication\BIDashboard\Files"
$reportTypes="URL","MainFrame","CodedUI","SOAPUI","WindowsService"
$Environments="DCORP","ICORP","ACORP","PCORP"
$HTMLTemplateFilePath=join-path $($Global:ScriptSourcePath)  -ChildPath "Notifications\Templates\EnvironmentStatus.html"
$HtmlBody=get-content Filesystem::$HTMLTemplateFilePath
$temphtmlfile = [string]::Format("{0}\EnvironmentStatusReport_{1}.htm",$Global:TempNotificationsFolder,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"))

$StatusHTML="<TABLE class='rounded-corner'>"
$StatusHTML+="<TR><TH>Tests/Checks</TH><TH>DCORP</TH><TH>ICORP</TH><TH>ACORP</TH><TH>PCORP</TH></TR>"
foreach($type in $reportTypes){
	$ReportRow="<TR><TD><B>$type - Check</B></TD>"
	foreach($Environment in $Environments){
		$ReportFile=get-childitem -Path filesystem::$global:EnvironmentHTMLReportLocation -Filter *$Environment*$type*
		if(!$ReportFile){
			$statuscolor='#ffff66'
			$status="Not Applicable"
		}
		else{
			$filecontent=Get-Content filesystem::$($ReportFile.FullName) 
			$statuscolor='#009933'
			$status="Passed"
			if($filecontent -ilike "*red*"){
				$statuscolor='#cc3300'
				$status="Failed"
			}
		}
		$ReportRow+=[string]::Format('<TD style="background:''{0}''">{1}</TD>',$statuscolor,$status)
	}
	$ReportRow+='</TR>'
	$StatusHTML+=$ReportRow
}
$StatusHTML+="</TABLE>"

#preparing the HTML Body to the mail
$HtmlBody = $HtmlBody -ireplace "#EnvReport#",$StatusHTML
$HtmlBody = $HtmlBody -ireplace "#DATETIME#",(Get-Date -Format "dd/MM/yyyy hh:mm")
$HtmlBody | Out-File Filesystem::$temphtmlfile
$stautsfile=$($BIDasboardLocation) +"\Environmentstatus.html" 
$HtmlBody | Out-File -Force Filesystem::$stautsfile 
Copy-Item  filesystem::$global:EnvironmentHTMLReportLocation  -Destination Filesystem::$BIDasboardLocation -Force

