PARAM($Environment)
Clear-Host

if(!$Environment){
	$Environment="DCORP"
}


if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
$query=Get-content "D:\BuildTeam\ClevaValidationQueries.sql"
$username='MERCATOR'
$password='mercator'
$dbName='CB1d'
$connection=CreateClevaDBConnection -User $username -Password $password -Database $dbName
$connection.Open()
$command=$connection.CreateCommand()
$command.CommandText=$query
$reader=$command.ExecuteReader()
$table= New-Object System.Data.DataTable
$table.Load($reader)
$rows=$table.Rows.Count
$columns=$table.Columns.Count

$HtmlBody=get-content Filesystem::$Global:CLEVADBSmokeMailTemplateFile
$temphtmlfile = [string]::Format("{0}\{1}_CLEVADB_{2}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"))
$Violations="<TABLE class='rounded-corner'>"
$Violations+="<TR align=center><TH colspan='$($columns)'>Database Check Status (Violations found :$($rows) )</TH></TR>"
$Violations+="<TR align=center>"
foreach($column in $table.Columns){
	
	$Violations+="<TH>$($column.ColumnName)</TH>"
}
$Violations+="</TR>"

Foreach($row in $table.Rows){
	$Violations+="<TR>"
	foreach($column in $table.Columns){
		$value=$row["$column"]
		if($value -ieq "Blocking"){
			$Violations+="<TD bgcolor='red'>$value</TD>"
		}else{
			$Violations+="<TD>$value</TD>"
		}
		
	}
	$Violations+="</TR>"
}
$Violations+="</TABLE>"

$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
$HtmlBody = $HtmlBody -ireplace "#TESTINFO#",$Violations
$HtmlBody | Out-File Filesystem::$temphtmlfile -Force

#Mail
#$mailrecipients= GetMailRecipients -ApplicationName "CLEVA" -NotificationType "DBCheck"
$mailrecipients="Shivaji.pai@baloise.be,Vinay.singh@baloise.be,gaby.vervoort@baloise.be,Kenneth.Hauttekeete@baloise.be"
$Mailsubject = "CLEVA $Environment Database Check Report " + ([datetime]::Now.ToString("dd-MM-yyyy_HHmm"))
SendMail -To  $mailrecipients -body $HtmlBody -subject $Mailsubject


#Cleanup
Remove-Item FileSystem::$temphtmlfile

