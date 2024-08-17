PARAM($Environment,$version)

if(!$Environment){
	$Environment="MIG"
	$version="99.19.129.0"
}

Clear-Host


Write-Host "`r`n===============================================CLEVA CLIENT CREATION==============================================="
Write-Host "Version     : " $version
Write-Host "Environment : " $Environment
Write-Host "JRE Version : " $clientJREVersion
Write-Host "===============================================CLEVA CLIENT CREATION===============================================`r`n"


#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$ErrorActionPreference='Stop'
$CitrixTransferlocation=Join-Path $global:TranferFolderBase -ChildPath "\CLEVA\Citrix_OneClient"
$clientsourcefolder="client"
if($Environment -ieq "DCORP" -or $Environment -ieq "PARAM"){
	$clientsourcefolder="client_debug"
}
Remove-PSDrive X -Force -ErrorAction SilentlyContinue
Remove-PSDrive Y -Force -ErrorAction SilentlyContinue
Remove-PSDrive B -Force -ErrorAction SilentlyContinue

$Release="R"+$version.split('.')[0]
$ClientsourceBasepath=join-path $Global:ClevaV14SourcePackages -ChildPath "$Release\$($Environment)\$version\$clientsourcefolder"
Write-Host $ClientsourceBasepath
New-PSdrive  -Name B -Root Filesystem::$ClientsourceBasepath -PSProvider "Filesystem" -Persist | Out-Null
$ClientsourceBasepath="B:\"
$ClientTemplatebasepath=Join-Path $Global:ClevaV14SourcePackages -ChildPath "templates\ClientTemplates"
New-PSdrive  -Name X -Root $ClientTemplatebasepath -PSProvider "Filesystem"  -Persist| Out-Null
$ClientTemplatebasepath="X:\"
#deployment location 
function DeployClient($type="")
{		Write-Host "=======================================$($Environment) - $($type)============================="
		Write-Host "CLEVA $Environment $type Client creation Start : "  $(get-Date)
		New-PSDrive  -Name Y -Root $CitrixTransferlocation -PSProvider "Filesystem" -Persist 
		$CurrentEnvClientTemplate=Join-Path $ClientTemplatebasepath -ChildPath "client$($type)\$($Environment)\"
		if($type){$type="-"+$type}
		$CitrixlocationClient=$Environment
		if($Environment -ieq 'MIG'){
			$CitrixlocationClient='DATAMIG'
		}
		$currentclient=[string]::Format("Y:\{0}-Current{1}\",$CitrixlocationClient,$type)
		$oldClientName=[string]::Format("{0}-old{1}",$CitrixlocationClient,$type)
		$oldClient=[string]::Format("Y:\{0}",$oldClientName)
		 
		if((-not(test-path Filesystem::$currentclient)) -or (-not(test-path Filesystem::$oldClient))){
			Write-Host "WARNING : There are no Clients for type - $type , The Client folders will be created"
			New-Item $currentclient -ItemType directory -Force 	| Out-Null	
			New-Item $oldClient -ItemType directory -Force 	| Out-Null	
		}
		Write-Host "Current Client - " $currentclient
		Write-Host "old Client     - " $oldClientName
		Remove-Item $oldClient -Force -Recurse -ErrorAction SilentlyContinue
		Rename-Item $currentclient -NewName $oldClientName -Force 
		New-Item $currentclient -ItemType directory -Force | Out-Null 
		Copy-Item  "$ClientsourceBasepath\*" -Destination $currentclient -Force -Recurse
		
		#startBat
		Copy-Item -Path "$CurrentEnvClientTemplate\*.bat" -Destination $currentclient -Force

		#tools folder
		Copy-Item -Path "$ClientTemplatebasepath\tools" -Destination $currentclient -Force -Recurse

		#jre folder
		$jrefolder="$($currentclient)jre\"
		New-Item $jrefolder -Force -ItemType Directory | out-null
#		Copy-Item -Path filesystem::"$($ClientTemplatebasepath)\jre\$clientJREVersion\*" -Destination "$jrefolder" -Force -Recurse
		if($type -ilike "*TOSCA*"){
			Copy-Item -Path filesystem::"$($ClientTemplatebasepath)\jre$Type\*" -Destination "$jrefolder" -Force -Recurse	
			Copy-Item -Path filesystem::"$($ClientTemplatebasepath)\plugins$Type\*" -Destination filesystem::"$($currentclient)\plugins\" -Force -Recurse	
		}
		
		#propertiesfile
		$t9file=join-path $CurrentEnvClientTemplate -childpath "\configuration\t9as.properties"
		Copy-Item -Path filesystem::$t9file -Destination "$currentclient\Configuration\" -Force -Recurse

		#ini file update
		$configfilesource=join-path $CurrentEnvClientTemplate -childpath "configuration\config.ini"
		$info=Get-Content filesystem::$configfilesource
		$destinationini=Join-Path $currentclient -childpath "configuration\config.ini"
		Add-Content -Path $destinationini -Value $info -Force
		
		$clevainifilesource=join-path $CurrentEnvClientTemplate -childpath "cleva.ini"
		$info=Get-Content filesystem::$clevainifilesource
		$destinationini=Join-Path $currentclient -childpath "cleva.ini"
		Add-Content -Path $destinationini -Value $info -Force
		
	if(-not(test-path $currentclient)){
		Write-Host "Client Deployment failed. No folder found"
	}
		Remove-PSDrive Y -Force
		Write-Host "CLEVA $Environment $type Client creation End  : "  $(get-Date)
		Write-Host "=======================================$($Environment) - $($type)============================="
}

DeployClient
DeployClient "Dyna"
DeployClient "Tosca"

Remove-PSDrive "X" -Force
Remove-PSDrive "B" -Force

