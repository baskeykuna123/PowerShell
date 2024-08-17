param([String]$Env,$BuildNumber)

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

Switch($ENV){ 
  			"DCORP" {
				$UserName="L001174" 
           		$tempUserPassword ="teCH_Key_DEV"
					 } 
  			"ICORP" {
				$UserName="L001173" 
           		$tempUserPassword ="teCH_Key_INT"
			} 
  			"ACORP" {
				$UserName="L001172" 
  		   		$tempUserPassword ="teCH_Key_ACC"
				}
		    "PCORP" {$UserName="L001171" 
           			 $tempUserPassword ="teCH_Key_PRO"}
	}

$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
#$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword
#$Cred = New-Object Management.Automation.PSCredential -ArgumentList $UserName, $tempUserPassword
$BuildVersion = $BuildNumber.Split("_")[$BuildNumber.Split("_").Length - 1]
$Application = $BuildNumber.Split("_")[$BuildNumber.Split("_").Length - 2]
$Branch = $BuildNumber.Split("_")[$BuildNumber.Split("_").Length - 3]
#$BuildDefenitionname = $BuildID.Replace("_" + $BuildVersion , "")
#$BuildVersion = $id.Replace("_" + $BuildVersion , "")
$subfolder="$Branch" + "_" + "$Application"
$file=$Application + '_' + 'DBBackup' + '_' + $BuildVersion + '.bak'
$file
$BackupPath="\\balgroupit.com\appl_data\BBE\Transfer\B&I\Databases\backup\$Application\$ENV"
$BackupPath
if (test-path -path $BackupPath){
write-host "Path Exists"
}
else{
new-item -path $BackupPath -itemtype Directory
}
$BackupPath
$bakfile=join-path $BackupPath -ChildPath $file
$ParametersPath=join-path $global:NewPackageRoot -ChildPath $Application\$subfolder\$BuildVersion
$ParametersPath
$XmlFile=Get-Childitem -path $ParametersPath -Filter '*_Resolved.xml' -File
$XmlFile
$XmlPath=join-path $ParametersPath -ChildPath $XmlFile
[XML]$XmlContent=get-content $XmlPath
$XmlContent
$XMLData=$XmlContent.Parameters.EnvironmentParameters.Environment | Where-Object {$_.name -ieq "$ENV"}
$DBName=$XMLData.add |Where-Object {$_.key -ilike "Baloise" + "$Application" + "DataBaseName"} | %{$_.Value}
$DBinstance=$XMLData.add |Where-Object {$_.key -ilike "Baloise" + "$Application" + "Datasource"} | %{$_.Value}
write-host "------------------------------------------------------------------"
write-host "DBinstance  ::" $DBinstance
write-host "DataBaseName ::" $DBName
write-host "XML File path::" $XmlPath
write-host "Backup Path  ::" $bakfile
write-host "------------------------------------------------------------------"

$cred = [pscredential]::new($UserName,(ConvertTo-SecureString -String $tempUserPassword -AsPlainText -Force))
Invoke-Sqlcmd -ServerInstance $DBinstance -Username $UserName -Password $tempUserPassword
Backup-SqlDatabase -ServerInstance $DBinstance -Database $DBName -Credential $cred -BackupFile $bakfile
