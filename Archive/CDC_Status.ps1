param([String]$Env,$BuildNumber)
cls
#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
$Env="ACORP"

Switch($ENV){ 
  			"DCORP" {
				$UserName="L001174" 
           		$tempUserPassword ="teCH_Key_DEV"
					 } 
  			"ICORP" {
				$UserName="L001173" 
           		$tempUserPassword ="teCH_Key_INT"
                $DBinstance="SQL-BED6-DE1751.balgroupit.com"
			} 
  			"ACORP" {
				$UserName="L001172" 
  		   		$tempUserPassword ="teCH_Key_ACC"
                $DBinstance="SQL-BEI6-IE1751.balgroupit.com"
				}
		    "PCORP" {
                $UserName="L001171" 
           		$tempUserPassword ="teCH_Key_PRO"
                $DBinstance="SQL-BEP6-PE1751.balgroupit.com"
                    }
	}

#$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
#$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword
#$Cred = New-Object Management.Automation.PSCredential -ArgumentList $UserName, $tempUserPassword
$reports=""
$report="<TABLE>"
$report+="<TR align=center><TH colspan='11'>$Env CDC</TH></TR>"
$DBinstance="SQL-BEI6-IE1751.balgroupit.com"
$test="ClevaOracleCB1A"
#$cred = [pscredential]::New($UserName,(ConvertTo-SecureString -String $tempUserPassword -AsPlainText -Force))
#Invoke-Sqlcmd -ServerInstance $DBinstance -Username $UserName -Password $tempUserPassword
$output=Invoke-Sqlcmd -ServerInstance $DBinstance -Username $UserName -Password $tempUserPassword -Query "SELECT TOP (1000) [status]
      ,[sub_status]
      ,[active]
      ,[error]
      ,[timestamp]
      ,[active_capture_node]
      ,[last_transaction_timestamp]
      ,[last_change_timestamp]
      ,[completed_transactions]
      ,[written_changes]
      ,[read_changes]
      ,[active_transactions]
  FROM [$test].[cdc].[xdbcdc_state]" 
  $report+=$output | ConvertTo-Html -as Table
$report+="</TABLE>"
#$report+="<TR align=center><TH colspan='11'>$Env CDC</TH></TR>"
#$report=$output | ConvertTo-Html -as Table
$reports+=$report
$Timestamp = [datetime]::Now.ToString("dd-MM-yyyy_HHmm")
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#DateTime#",$Timestamp
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#StatusReport#",$reports
#$HtmlBodyStatus | Out-File Filesystem::$EnvironmentStatusHTM -Force
$TemplatefilePath=join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\CDC-Report.html"
$TemplatefilePath
$HtmlBody = [system.IO.File]::ReadAllLines($TemplatefilePath)
$HtmlBody = $HtmlBody -ireplace "#ReportINFO#",$reports
$HtmlBody = $HtmlBody -ireplace "#ENV#",$Env
$temphtmlfile="E:\temp.htm"
$HtmlBody | Out-File Filesystem::$temphtmlfile
SendMailWithoutAdmin -body ([string]$HtmlBody) -To "pankaj.kumarjha@baloise.be" -subject "$($Env) CDC Report"