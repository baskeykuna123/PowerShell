PARAM($Environment,$version,$SpecialSuffix="")

if(!$Environment){
	$Environment="ACC"
	$version="29.3.42.16"
	$SpecialSuffix="JBoss_"
	
}

Clear-Host
$version=$SpecialSuffix+$version
  
# DB server information
$DBuserid="L001171"
$DBpassword="teCH_Key_PRO"
$dbserver="sql-be-buildp"
$dbName="BaloiseReleaseVersions"

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
$CreateToscaClient=$true
switch ($Environment) 
      {
	  	{($_ -ieq "PLAB")-or ($_ -ieq "PAR")} { 
												$ClevaEnv="PAR"
												$CitrixEnvironment="PARAM"
												$CreateToscaClient=$false
											}
		{($_ -ieq "DCORP")-or ($_ -ieq "DEV")} { 
												$ClevaEnv="DEV"
												$CitrixEnvironment="DCORP"
											}
		{($_ -ieq "ICORP")-or ($_ -ieq "INT")} { 
												$ClevaEnv="INT"
												$CitrixEnvironment="ICORP"
											}
		{($_ -ieq "ACORP")-or ($_ -ieq "ACC")} { 
												$ClevaEnv="ACC"
												$CitrixEnvironment="ACORP"
											}
		{($_ -ieq "PCORP")-or ($_ -ieq "PRD")} { 
												$ClevaEnv="PRD"
												$CitrixEnvironment="PCORP"
												$CreateToscaClient=$false
											}
		{($_ -ieq "MCORP")-or ($_ -ieq "MIG")} { 
												$ClevaEnv="MIG"
												$CitrixEnvironment="DATAMIG"
												$CreateToscaClient=$false
											}
		{($_ -ieq "MCORP4")-or ($_ -ieq "MIG4")} { 
												$ClevaEnv="MIG4"
												$CitrixEnvironment="MIG4"
												$CreateToscaClient=$false
											}
     }

#switch ($Environment) 
#      {
#	  	"PLAB" { $ClevaEnv="PAR"}
#	    "DCORP" { $ClevaEnv="DEV"}
#        "ICORP" { $ClevaEnv="INT"}
#		"ACORP" { $ClevaEnv="ACC"}
#		"PCORP" { $ClevaEnv="PRD"}
#		"MIG"   { $ClevaEnv="MIG"}
#		"MIG3"  { $ClevaEnv="MIG3"}
#		"MIG4"  { $ClevaEnv="MIG4"}
#     }
#
#
#switch($Environment){
#		"PLAB" { $Environment="PARAM"}
#	    "DEV" { $Environment="DCORP"}
#        "INT" { $Environment="ICORP"}
#		"ACC" { $Environment="ACORP"}
#		"PRD" { $Environment="PCORP"}
#}






#deployment location 
function DeployClient($type,$version,$clientfolder)
{		New-PSDrive  -Name U -Root "\\balgroupit.com\appl_data\BBE\Transfer\CLEVA\Citrix_OneClient" -PSProvider "Filesystem" -Persist
		$citrixbaseshare="U:\"
		$source=[string]::Format("D:\ClevaPackages\$ClevaEnv\{0}\{1}\",$version,$clientfolder)
		$currentclient=[string]::Format("$citrixbaseshare\{0}-Current{1}\",$CitrixEnvironment,$type)
		$oldClient=[string]::Format("$citrixbaseshare\{0}-old{1}\",$CitrixEnvironment,$type)
		if((-not(test-path $currentclient)) -or (-not(test-path $oldClient))){
			Write-Host "Client Deployment failed. No folder found"
			Exit 1
		}
		
#		New-Item Filesystem::$currentclient -Force -ItemType Directory
#		New-Item Filesystem::$oldClient -Force -ItemType Directory
		Remove-Item $oldClient* -Force -Recurse
		Copy-Item $currentclient* -Destination $oldClient -Force -Recurse
		Remove-Item $currentclient* -Force -Recurse
		Copy-Item $source* -Destination $currentclient -Force -Recurse
		
	if(-not(test-path $currentclient)){
		Write-Host "Client Deployment failed. No folder found"
	}
		Remove-PSDrive U -Force
}

function CreateClient($type,$version,$clientfolder){
	$actualversion=$version.Replace($Environment,"")
	$actualversion=$actualversion -iReplace("JBOSS_","")
	$selectQuery="Select * from CLEVAVersions where Cleva_Version='$actualversion'"
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
	$date=[DateTime]::Now.ToString("yyyyMMdd")
	$release=$actualversion.split('.')[0]
	$dyna=""
	if($type -like "*Dyna*"){
		$dyna="_Dyna"
	}
		$ITNclientFolder="client"
		if($ClevaEnv -match "PAR" -or $ClevaEnv -match "DEV"){ 
		$ITNclientFolder="client_debug_assurance"
	}
	$clientpath=[string]::Format("D:\ClevaPackages\$ClevaEnv\{0}\{1}\",$version,$clientfolder)
	$startbat=[string]::Format("D:\Delivery\Deploy\packages\{0}\templates\{1}\cleva_{1}_start{2}.bat",$type,$ClevaEnv,$dyna)
	$toolsfoldersource=[string]::Format("D:\Delivery\Deploy\packages\{0}\templates\tools",$type)
	$jresource=[string]::Format("D:\Delivery\Deploy\packages\{0}\templates\Java\Jre",$type)
	$ITNClient=[string]::Format("D:\Delivery\Deploy\packages\ITN\{0}\{1}\ClevaClient_{0}.zip",$select.ITN_Version,$ITNclientFolder)
	$jbossfolder=[string]::Format("D:\Delivery\Deploy\packages\TechnicalTeam\{0}\JBoss\",$select.MIDC_Version)
	$jbossfile=[string]::Format("JBoss_{0}.zip",$select.MIDC_Version)
	cmd /c "unzip.exe -oq $jbossfolder$jbossfile -d $jbossfolder"
	$midclient=[string]::Format("D:\Delivery\Deploy\packages\TechnicalTeam\{0}\Jboss\updatesite-dev-specifique.zip",$select.MIDC_Version)
	$t9source=[string]::Format("D:\Delivery\Deploy\packages\{0}\templates\{1}\ClientConfig_T9\t9as.properties_{1}{2}",$type,$ClevaEnv,$dyna)
	$configfilesource=[string]::Format("D:\Delivery\Deploy\packages\{0}\templates\{1}\ClientConfig_Ini\ini_{1}{2}.txt",$type,$ClevaEnv,$dyna)
	$clevainisource=[string]::Format("D:\Delivery\Deploy\packages\{0}\templates\{1}\ClevaConfig_Ini\ini_cleva_{1}{2}.txt",$type,$ClevaEnv,$dyna)




#creating the ini File
$versionfile=$clientpath+"version.ini"
Set-Content -Path $versionfile -Value $release -Force

#start.bat

Copy-Item -Path $startbat -Destination $clientpath -Force

#tools folder
Copy-Item -Path $toolsfoldersource -Destination $clientpath -Force -Recurse

#jre folder
Copy-Item -Path $jresource -Destination $clientpath -Force -Recurse

#unzipping content
cmd /c "unzip.exe -oq $ITNClient -d $clientpath"
cmd /c "unzip.exe -oq $midclient -d $clientpath"

#propertiesfile
$t9file=$clientpath+"\configuration\t9as.properties"
Copy-Item -Path $t9source -Destination $t9file -Force -Recurse

#ini file update
$destconfigini=$clientpath+"\configuration\config.ini"
$info=Get-Content $configfilesource
Add-Content -Path $destconfigini -Value $info -Force

$destconfigini=$clientpath+"\cleva.ini"
$info=Get-Content $clevainisource
Add-Content -Path $destconfigini -Value $info -Force


}

function PrepareTOSCAClient($version){
	$clientSource=[string]::Format("D:\ClevaPackages\$ClevaEnv\{0}\Client\",$version)
	$clientdestination=[string]::Format("D:\ClevaPackages\$ClevaEnv\{0}\client_Tosca\",$version)
	$toscaJreSource="D:\BuildTeam\Templates\TOSCACLIENT\jre\"
	$pluginSource="D:\BuildTeam\Templates\TOSCACLIENT\plugins\"
	$batfileSource=[string]::Format("D:\Delivery\Deploy\packages\Citrix_Tosca\templates\{0}\cleva_{0}_start.bat",$ClevaEnv)
	$poilicyfile=$clientdestination+"Jre\lib\security\java.policy"
	if(test-path Filesystem::$clientdestination){
		Remove-Item "$clientdestination\*" -Force -Recurse
	}
	New-Item -ItemType Directory -Path $clientdestination -Force | out-Null
	Copy-Item -Path $clientSource* -Destination $clientdestination -Force -Recurse
	Copy-Item $batfileSource -Destination $clientdestination -Force -Recurse
	$configfilepath=$clientdestination+'Configuration\config.ini'
	$configline='osgi.bundles=org.eclipse.equinox.common@2\:start,org.eclipse.update.configurator@3\:start,org.eclipse.core.runtime@start,TOSCAJavaStarter@start'
	Add-Content -Path $configfilepath -Value $configline
	$pluginsfolder=$clientdestination+'plugins\'
	$jrefolder=$clientdestination+'Jre\'
	Copy-Item "$toscaJreSource*" -Destination $jrefolder -Force -Recurse
	Copy-Item "$pluginSource*" -Destination $pluginsfolder -Force

#$policydata=Get-Content $poilicyfile
#
#$searchdata='permission java.net.SocketPermission "localhost:1024-", "listen";'
#$replacedata=@'
#permission java.net.SocketPermission "localhost:1024-", "listen,accept,connect,resolve";
#permission java.net.SocketPermission "10.253.64.100:1024-", "listen,accept,connect,resolve"; 
#'@
#$policydata=$policydata -ireplace $searchdata,$replacedata
#Set-Content $poilicyfile -Value $policydata -Force
}

CreateClient "Citrix" $version "client"
CreateClient "Citrix_dyna" $version "client_dynatrace"
if($CreateToscaClient){
	PrepareTOSCAClient $version	
}


DeployClient "" $version "client"
DeployClient "-dyna" $version "client_dynatrace"
if($CreateToscaClient){
	DeployClient "-Tosca" $version "client_Tosca"
}