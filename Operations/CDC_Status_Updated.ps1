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

$Cleva_ICORP_query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [ClevaOracleCB1I].[cdc].[xdbcdc_state]"
$Cleva_ACORP_query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [ClevaOracleCB1A].[cdc].[xdbcdc_state]"
$Cleva_PCORP_query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [ClevaOracleCB1P].[cdc].[xdbcdc_state]"

$NINA_ICORP_query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [NINAOracleNB1I].[cdc].[xdbcdc_state]"
$NINA_ACORP_query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [NINAOracleNB1A].[cdc].[xdbcdc_state]"
$NINA_PCORP_query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [NINAOracleNB1P].[cdc].[xdbcdc_state]"

$Cleva_ICORP_output= Invoke-Sqlcmd -ServerInstance "SQL-BED6-DE1751.balgroupit.com\DE1751" -Username "L001173" -Password "teCH_Key_INT" -Query $Cleva_ICORP_query | ConvertTo-Html -as Table -Property status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
$Cleva_ACORP_output= Invoke-Sqlcmd -ServerInstance "SQL-BEI6-IE1751.balgroupit.com\IE1751" -Username "L001172" -Password "teCH_Key_ACC" -Query $Cleva_ACORP_query | ConvertTo-Html -as Table -Property status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
$Cleva_PCORP_output= Invoke-Sqlcmd -ServerInstance "SQL-BEP6-PE1751.balgroupit.com\PE1751" -Username "L001171" -Password "teCH_Key_PRO" -Query $Cleva_PCORP_query | ConvertTo-Html -as Table -Property status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
$NINA_ICORP_output= Invoke-Sqlcmd -ServerInstance "SQL-BED6-DE1751.balgroupit.com\DE1751" -Username "L001174" -Password "teCH_Key_DEV" -Query $NINA_ICORP_query | ConvertTo-Html -as Table -Property status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
$NINA_ACORP_output= Invoke-Sqlcmd -ServerInstance "SQL-BEI6-IE1751.balgroupit.com\IE1751" -Username "L001172" -Password "teCH_Key_ACC" -Query $NINA_ACORP_query | ConvertTo-Html -as Table -Property status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
$NINA_PCORP_output= Invoke-Sqlcmd -ServerInstance "SQL-BEP6-PE1751.balgroupit.com\PE1751" -Username "L001171" -Password "teCH_Key_PRO" -Query $NINA_PCORP_query | ConvertTo-Html -as Table -Property status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions

$ICORP_report=$Cleva_ICORP_output
$NINA_ICORP_report=$NINA_ICORP_output
$ACORP_report=$Cleva_ACORP_output
$NINA_ACORP_report=$NINA_ACORP_output
$PCORP_report=$Cleva_PCORP_output
$NINA_PCORP_report=$NINA_PCORP_output
#$report+="</TABLE>"
$Cleva_ICORP_reports+=$ICORP_report
$Cleva_ACORP_reports+=$ACORP_report
$Cleva_PCORP_reports+=$PCORP_report
$NINA_ICORP_reports+=$NINA_ICORP_report
$NINA_ACORP_reports+=$NINA_ACORP_report
$NINA_PCORP_reports+=$NINA_PCORP_report

$TemplatefilePath = join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\CDC-Report.html"
$HtmlBody = [system.IO.File]::ReadAllLines($TemplatefilePath)
$HtmlBody = $HtmlBody -ireplace "#ClevaICORPReportINFO#",$Cleva_ICORP_reports
$HtmlBody = $HtmlBody -ireplace "#ClevaACORPReportINFO#",$Cleva_ACORP_reports
$HtmlBody = $HtmlBody -ireplace "#ClevaPCORPReportINFO#",$Cleva_PCORP_reports
$HtmlBody = $HtmlBody -ireplace "#NINAICORPReportINFO#",$NINA_ICORP_reports
$HtmlBody = $HtmlBody -ireplace "#NINAACORPReportINFO#",$NINA_ACORP_reports
$HtmlBody = $HtmlBody -ireplace "#NINAPCORPReportINFO#",$NINA_PCORP_reports
$HtmlBody = $HtmlBody -ireplace "#ENV#",$ENV
#$HtmlBody | Out-File Filesystem::$temphtmlfile
SendMail -To $MailRecipients -subject "$($Env) CDC Report"t -body ([string]$HtmlBody)
#SendMailWithoutAdmin -body ([string]$HtmlBody) -To "deepak.gorichela@baloise.be" -subject "CDC Report"