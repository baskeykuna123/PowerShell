PARAM
	(
	[string]$SourceDirectory,
	[string]$BuildNumber,
	[string]$DeploymentDate
	)
	
if(!$SourceDirectory){
	$SourceDirectory="D:\Shivaji\TFSProd\Baloise\NINA\"
	$BuildNumber="Staging_NINA_20171127.1"
}


#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$DeploymentBatchFileTemplate=@"
@ECHO OFF
SET /a LogFilePath=%1

"@


clear
$DeploymentDirectory=join-path $SourceDirectory -ChildPath "\Deployment\"
$DeploymentTemplates=join-path $DeploymentDirectory -ChildPath "Templates"


if(!$DeploymentDate){
	$DeploymentDate=(Get-Date -Format yyyyMMdd)
}

$encharacters=@("/",";")
Write-Host "================================Input Pararmeters=============================================="
Write-Host "Source Directory : " $SourceDirectory
Write-Host "BuildNumber      : " $BuildNumber
Write-Host "BuildNumber      : " $DeploymentDate
Write-Host "================================Input Pararmeters=============================================="

$packagesFolder=[string]::Format("{0}\NINA\{1}_{2}\{3}",$global:NewPackageRoot,$BuildNumber.split('_')[0],$BuildNumber.split('_')[1],$BuildNumber.split('_')[2])
$DatabasepackagesFolder=Join-Path $packagesFolder -ChildPath "Baloise.Nina.Database"
#creating New DB DeploymentFolder
New-Item $DatabasepackagesFolder -ItemType Directory -Force | Out-Null
$paramfile=(get-childitem $SourceDirectory -file -recurse -filter "*Parameters.xml").FullName
copy-item $($paramfile) -Destination $packagesFolder -force
$DeploymentParametersFile=(get-childitem $packagesFolder -file -filter "*Parameters.xml").FullName 
$scriptPath = [String]::Format("{0}\build\ResolveParameterXml.ps1",$ScriptDirectory)
#call the script
& $scriptPath -verbose $DeploymentParametersFile -BuildVersion $BuildNumber

$DeploymentParametersFile=(get-childitem $packagesFolder -recurse -file -filter "*Resolved.xml").FullName 
$Parameters=[xml] (get-content $DeploymentParametersFile)
$Environments=$Parameters.Parameters.EnvironmentParameters.Environment
$SchemaExecutionSequence=($Parameters.Parameters.GlobalParameters.add |  where {$_.key -ieq "NinaDataBaseDeploymentSchemaSequence"}).value
$ArtifactExecutionSequence=($Parameters.Parameters.GlobalParameters.add |  where {$_.key -ieq "NinaDataBaseDeploymentArtifactSequence"}).value



$Revoke = "Templates/Revoke_connect_from_core_schemas.sql"
function Prepare-DBScripts {
PARAM([string]$Templatefile,$Scripts,$ScripType,$Schema)
	#$ArtifactsforEndCharacter=@("Packages","Scripts")
	#foreach($script in $Scripts){
			
	#		Set-ItemProperty  $script.FullName -Name IsReadOnly -Value $false
	#		$lastCharacter=Get-Content $($script.FullName) | Select-Object -last 1
	#		$lastCharacter=$lastCharacter.trim()
			
	#		if(($ArtifactsforEndCharacter -icontains $ScripType) -and ($lastCharacter -notin $encharacters)){
	#			Write-Host "=========================================="
	#			Write-host "Script Name :" $script.Name
	#			Write-host "Last Char   :" $lastCharacter
	#			Write-Host "=========================================="
	#			Add-Content $script.FullName -Value "`r`n/"

	#		}
	#}
	$Environments | foreach {
		$dbname=($_.add | where {$_.key -ieq "NinaDataBaseName"}).value
		$user=Get-Credentials -Environment $($_.name) -ParameterName "NinaDatabaseDeploymentUser"
		$password=Get-Credentials -Environment $($_.name) -ParameterName "NinaDatabaseDeploymentUserPassword"
		$Deploymentsqlfile=[string]::Format("{0}\{1}.sql",$DatabasepackagesFolder,$($_.name))
		$DeploymentfileName=[string]::Format("{0}\{1}\{2}.{3}",$DatabasepackagesFolder,$Schema,$($_.name),(split-path $templatefile -leaf))
		$DeploymentBatchfile=[string]::Format("{0}\{1}.bat",$DatabasepackagesFolder,$($_.name))

		$setschema="CONN $($user)[$Schema]/$($password)@'ora1$($dbname).balgroupit.com:12051/$($dbname).BALGROUPIT.COM'"
		Add-content $Deploymentsqlfile -Value $setschema -Encoding Ascii
		$commanfile=$Deploymentsqlfile.replace("$DatabasepackagesFolder\","")
		$batchfileContent="sqlplus.exe $($user)/$($password)@'ora1$($dbname).balgroupit.com:12051/$($dbname).BALGROUPIT.COM' @$commanfile > $($_.name).txt"
		set-content $DeploymentBatchfile -Value $batchfileContent -Force
		$scriptlist=""
		foreach($script in $Scripts){
			if(Test-Path $Templatefile){
				$template=Get-Content $templatefile
			}
			$scriptpath=($Script.FullName).replace("$DatabasepackagesFolder\","")
			$SqlArtifactName=[System.IO.Path]::GetFileNameWithoutExtension($script.Name)
			$SqlArtifactName=$SqlArtifactName -replace "ALTER_TABLE_"
			$SqlArtifactName=$SqlArtifactName -replace "CREATE_TABLE_"
			$SqlArtifactName=$SqlArtifactName -replace "ALTER_SEQUENCE_"
			$SqlArtifactName=$SqlArtifactName -replace "CREATE_SEQUENCE_"
			
			$template=$template -replace "<LKey_user>",$user 
			$template=$template -replace "<LKey_passwd>",$password 
			$template=$template -replace "<DB_name>","ora1$($dbname).balgroupit.com:12051/$($dbname).BALGROUPIT.COM" 
			switch($ScripType){
				"Packages"	{
								$template=$template -ireplace "<Package_name>",$SqlArtifactName
							}

				"Tables"	{
								$template=$template -ireplace "<Table_name>",$SqlArtifactName
							}
				"Sequences"	{
								$template=$template -ireplace "<Sequence_name>",$SqlArtifactName
							}
			}
			Add-Content $DeploymentfileName -Value $template
			$scriptlist+="`r`n@@$($scriptpath)"
		}
		if($ScripType -ine "Scripts"){
			$synonymPath=$DeploymentfileName.replace("$DatabasepackagesFolder\","")
			$scriptlist+="`r`n@@$($synonymPath)"
		}
		Add-Content $Deploymentsqlfile -Value $scriptlist
	}
	

}




$Deploymetfolder=Get-ChildItem -Path $DeploymentDirectory  -Directory -Filter "$($DeploymentDate)*" | sort | select -First 1 
#checking if there is a deployment data folder
if(!$Deploymetfolder){
	Write-Host "There are no Database Deployment folders nothing to do "
	Exit 0
	
}
$Deploymetfolder | foreach {
	Copy-Item "$($_.FullName)\*" -Destination $DatabasepackagesFolder -Force -Recurse
}
Copy-Item $DeploymentTemplates -Destination $DatabasepackagesFolder\ -Force -Recurse



$configfile = "Templates/Config.sql"
$Grant = "Templates/Grant_connect_to_core_schemas.sql"
$Environments | foreach {
	$Deploymentsqlfile=[string]::Format("{0}\{1}.sql",$DatabasepackagesFolder,$($_.name))
	Add-content $Deploymentsqlfile -Value "@@$($configfile)" -Encoding Ascii
	Add-content $Deploymentsqlfile -Value "@@$($Grant)" -Encoding Ascii
	} 

foreach($schema in $SchemaExecutionSequence.Split(',')){
	foreach($artifact in $ArtifactExecutionSequence.split(',')){
		$ScriptFolder=[string]::Format("{0}\{1}\{2}\",$DatabasepackagesFolder,$schema,$artifact)
		$templatefile=[string]::Format("{0}\Templates\{1}_{2}_priv_syn.sql",$DatabasepackagesFolder,$schema,$artifact)
		if(Test-Path $ScriptFolder){
			$Artifacts=Get-ChildItem $ScriptFolder -File | sort
			Prepare-DBScripts -Templatefile $templatefile -Scripts $Artifacts -ScripType $artifact -Schema $schema
		}
	}
}

$Environments | foreach {
	$dbname=($_.add | where {$_.key -ieq "NinaDataBaseName"}).value
	$user=Get-Credentials -Environment $($_.name) -ParameterName "NinaDatabaseDeploymentUser"
	$password=Get-Credentials -Environment $($_.name) -ParameterName "NinaDatabaseDeploymentUserPassword"
	$Revoke = "Templates\Revoke_connect_from_core_schemas.sql"
	$Deploymentsqlfile=[string]::Format("{0}\{1}.sql",$DatabasepackagesFolder,$($_.name))
	Add-content $Deploymentsqlfile -Value "CONN $($user)/$($password)@'ora1$($dbname).balgroupit.com:12051/$($dbname).BALGROUPIT.COM'" -Encoding Ascii
	Add-content $Deploymentsqlfile -Value "@@$($Revoke)" -Encoding Ascii
	Add-content $Deploymentsqlfile -Value "@@Templates\Schema_compile.sql" -Encoding Ascii
	Add-content $Deploymentsqlfile -Value "exit" -Encoding Ascii

}