param(
[String]$Environment,
[String]$ClevaClientStatus,
[String]$TalkClientStatus
)
Clear-Host
if(!$Environment){
	$Environment="ACORP"
	$ClevaClientStatus="SUCCESS"
	$TalkClientStatus="SUCCESS"
}

$OverallStatus="Successful"
#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$TemplateFile=join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\EnvironmentStatus.html"
$HtmlBody=get-content FileSystem::$TemplateFile
$temphtmlfile = [string]::Format("{0}\{1}_STATUS_{2}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"))
Get-ChildItem Filesystem::$global:EnvironmentHTMLReportLocation -Filter "*$Environment*" | foreach {
$data=Get-Content Filesystem::$($_.FullName)
if($($_.Name) -like "*URL*"){
	$HtmlBody = $HtmlBody -ireplace "#URL#",$data 
}
if($($_.Name) -like "*SOAPUI*"){
	$HtmlBody = $HtmlBody -ireplace "#SOAPUI#",$data 
}
}

#preparing Client Status table for Report
$ClientStatus="<TABLE class='rounded-corner'>"
$ClientStatus+="<TR align=center><TH colspan='2'>Clinet Status : $($env)</TH></TR>"
$ClientStatus+="<TR align=center><TD>CLEVA CLient</TD><TD>$ClevaClientStatus</TD></TR>"
$ClientStatus+="<TR align=center><TD>TALK CLient</TD><TD>$TalkClientStatus</TD></TR>"
$ClientStatus+="</TABLE>"
$HtmlBody = $HtmlBody -ireplace "#CLIENT#",$ClientStatus 

$HtmlBody | Out-File Filesystem::$temphtmlfile
