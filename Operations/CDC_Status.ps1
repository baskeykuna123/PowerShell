param([String]$MailRecipients)
cls
#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=Split-Path (Split-Path $MyInvocation.MyCommand.Definition -Parent) -parent
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop



#$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
#$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword
#$Cred = New-Object Management.Automation.PSCredential -ArgumentList $UserName, $tempUserPassword
$ICORP_reports=""
$ACORP_reports=""
$PCORP_reports=""

$ICORP_query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [ClevaOracleCB1I].[cdc].[xdbcdc_state]"
$ACORP_query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [ClevaOracleCB1A].[cdc].[xdbcdc_state]"
$PCORP_query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [ClevaOracleCB1P].[cdc].[xdbcdc_state]"

$ICORP_output= Invoke-Sqlcmd -ServerInstance "SQL-BED6-DE1751.balgroupit.com\DE1751" -Username "L001173" -Password "teCH_Key_INT" -Query $ICORP_query | ConvertTo-Html -as Table -Property status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
$ACORP_output= Invoke-Sqlcmd -ServerInstance "SQL-BEI6-IE1751.balgroupit.com\IE1751" -Username "L001172" -Password "teCH_Key_ACC" -Query $ACORP_query | ConvertTo-Html -as Table -Property status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
$PCORP_output= Invoke-Sqlcmd -ServerInstance "SQL-BEP6-PE1751.balgroupit.com\PE1751" -Username "L001171" -Password "teCH_Key_PRO" -Query $PCORP_query | ConvertTo-Html -as Table -Property status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
$ICORP_report=$ICORP_output
$ACORP_report=$ACORP_output
$PCORP_report=$PCORP_output
#$report+="</TABLE>"
$ICORP_reports+=$ICORP_report
$ACORP_reports+=$ACORP_report
$PCORP_reports+=$PCORP_report

$TemplatefilePath = join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\CDC-Reporttest.html"
$HtmlBody = [system.IO.File]::ReadAllLines($TemplatefilePath)
$HtmlBody = $HtmlBody -ireplace "#ICORPReportINFO#",$ICORP_reports
$HtmlBody = $HtmlBody -ireplace "#ACORPReportINFO#",$ACORP_reports
$HtmlBody = $HtmlBody -ireplace "#PCORPReportINFO#",$PCORP_reports
$HtmlBody = $HtmlBody -ireplace "#ENV#",$ENV
#$HtmlBody | Out-File Filesystem::$temphtmlfile
SendMail -To $MailRecipients -subject "$($Env) CDC Report"t -body ([string]$HtmlBody)
#SendMailWithoutAdmin -body ([string]$HtmlBody) -To "deepak.gorichela@baloise.be" -subject "CDC Report"