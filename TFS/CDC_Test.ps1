param([String]$ENV,$BuildNumber)

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

Clear-Host

$ENV="PCORP"

Switch($ENV){ 
  			"DCORP" {
				$UserName="L001174" 
           		$tempUserPassword ="teCH_Key_DEV"
					 } 
  			"ICORP" {
				$UserName="L001173" 
           		$tempUserPassword ="teCH_Key_INT"
                $DBinstance="SQL-BED6-DE1751.balgroupit.com"
                $test="ClevaOracleCB1I"
			} 
  			"ACORP" {
				$UserName="L001172" 
  		   		$tempUserPassword ="teCH_Key_ACC"
                $DBinstance="SQL-BEI6-IE1751.balgroupit.com"
                $test="ClevaOracleCB1A"
				}
		    "PCORP" {
                $UserName="L001171" 
           		$tempUserPassword ="teCH_Key_PRO"
                $DBinstance="SQL-BEP6-PE1751.balgroupit.com"
                $test="ClevaOracleCB1P"
                    }
	}

$temphtmlfile = join-path $Global:TempNotificationsFolder -childpath "CDC_Report.htm"
$reports=""
$report="<TR align='center'><TH colspan='4'>$ENV CDC Report</TH></TR>"
$report+="<TR align='center'><TD>Status</TD><TD>SubStatus</TD><TD>Active</TD><TD>Error</TD></TR>"
$query = "SELECT status,sub_status,active,error,timestamp,active_capture_node,last_transaction_timestamp,last_change_timestamp,completed_transactions,written_changes,read_changes,active_transactions
         FROM [$test].[cdc].[xdbcdc_state]"

$output= Invoke-Sqlcmd -ServerInstance $DBinstance -Username $UserName -Password $tempUserPassword -Query $query
$Status=$output.status
$Sub_Status=$output.sub_status
$Active=$output.active
$field=$output.error
$report+="<TR align='center'><TD>$Status</TD><TD>$Sub_Status</TD><TD>$Active</TD><TD>$field</TD></TR>"
$report+="</TABLE>"
$reports+=$report

$TemplatefilePath=join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\CDC-Report.html"
$HtmlBody = [system.IO.File]::ReadAllLines($TemplatefilePath)
$HtmlBody = $HtmlBody -ireplace "#ReportINFO#",$reports
$HtmlBody = $HtmlBody -ireplace "#ENV#",$ENV
$HtmlBody | Out-File Filesystem::$temphtmlfile
$subject="$($Env) CDC Report"
SendMailWithoutAdmin -To "Deepak.Gorichela@baloise.be"  -body ([string]$HtmlBody) -subject $subject