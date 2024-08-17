PARAM($Release,$MailRecipients)

clear
if(!$Release){
 $Release="R31"
 $MailRecipients="Shivaji.pai@baloise.be"
}

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$PackageSourceFolder=[string]::Format("{0}\Cleva\sources\{1}",$global:NewPackageRoot,$Release)

$HTMLTemplateFilePath=join-path $($Global:ScriptSourcePath)  -ChildPath "Notifications\Templates\CLEVA_ReleaseVersionInfo.html"
$HtmlBody=get-content Filesystem::$HTMLTemplateFilePath
$temphtmlfile = [string]::Format("{0}\CLEVA_ReleaseInfo_{1}.htm",$Global:TempNotificationsFolder,$Release)

$VersionHTML="<TABLE class='rounded-corner'>"
$VersionHTML+="<TR><TH><B>Version</B></TH><TH><B>SQL Scripts</B></TH><TH><B>Mpars</B></TH></TR>"
$Versioninfo=""
#inserting the pacakge values into the database
$selectquery=[string]::Format("Select * from [BuildVersions] where Release='{0}' and Status='AVAILABLE' and ApplicationID=3 order by builddate asc",$Release.Replace("R",""))
$select=ExecuteSQLonBIVersionDatabase -SqlStatement $selectquery
$select | foreach {
$Versionfolder=Join-Path $PackageSourceFolder -ChildPath $($_.Version)
$mparfile=(get-childitem -Path Filesystem::$Versionfolder -Filter "mpars_*").FullName
write-host "Version :$($_.Version)"
if($mparfile){
$mpars=Get-Content filesystem::$mparfile
}
else{
$mpars="No Mpars"
}
$SQlfolder=Join-Path $PackageSourceFolder -ChildPath "$($_.Version)\database\cleva\sql"
$Sqlfiles=get-childitem -Path Filesystem::$SQlfolder -Filter "*.sql"| where {$_.Name -ine "summary.sql"}| sort
if($Sqlfiles){
	$Sqls=$Sqlfiles.Name
}
else{
$sqls="NO SQL Scripts"

}
$Versioninfo+=[string]::Format("<TR><TD>{0}</TD><TD>{1}</TD><TD>{2}</TD></TR>",$($_.Version),($sqls -join "<BR/>"),($mpars -join "<BR/>"))
}
$VersionHTML+=$Versioninfo
$VersionHTML+="</TABLE>"

#preparing the HTML Body to the mail
$HtmlBody = $HtmlBody -ireplace "#Relase#",$Release
$HtmlBody = $HtmlBody -ireplace "#VersionInfo#",$VersionHTML
$HtmlBody | Out-File Filesystem::$temphtmlfile

$Mailsubject = "Cleva $Release MPARS and SQL Info"
SendMailWithoutAdmin -To  $MailRecipients -body $HtmlBody -subject $Mailsubject
