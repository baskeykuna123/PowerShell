# Enable -Verbose option
[CmdletBinding()]

param([String]$TfsSourceFolder,[String]$PackageVersion,[String]$PackageName,[String]$PackageRootPath,[String]$Environment)

if (!$TfsSourceFolder){
	$TfsSourceFolder = "E:\Kurt\WiseMigration\s"
	$VerbosePreference = "Continue"
    $PackageVersion="35.7.5.0"
    $PackageName = "Mercator.Legacy.BaseClient.zip"
    $PackageRootPath="\\balgroupit.com\appl_data\BBE\Packages\MyBaloiseClassic"
    $Environment="acorp"
	#$VerbosePreference = "SilentlyContinue"
}
cls

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

Write-Host "TfsSourceFolder= $TfsSourceFolder"
Write-Host "PackageVersion= $PackageVersion"
Write-Host "PackageName= $PackageName"
Write-Host "PackageRootPath= $PackageRootPath"
Write-Host "start copying to local 0-version folder"

#recreate $Version0Folder folder
$VersionZeroFolder= Join-Path $TfsSourceFolder -ChildPath "0-version"
If(test-path $VersionZeroFolder) {
	Remove-Item -Path $VersionZeroFolder -Force -Recurse
}
New-Item -ItemType Directory -Force -Path $VersionZeroFolder | Out-Null

#check package zip
$PackageFullName=Join-Path $PackageRootPath -ChildPath $PackageVersion | Join-Path -ChildPath $PackageName
If(!(test-path $PackageFullName)) {
	exit 1
}

#copy and unzip package to temp location
$tempFolder= Join-Path $TfsSourceFolder -ChildPath "temp"
If(test-path $tempFolder) {
	Remove-Item -Path $tempFolder -Force -Recurse
}
New-Item -ItemType Directory -Force -Path $tempFolder | Out-Null
Copy-Item $PackageFullName -Destination $tempFolder

$LocalDeploymentRoot=Join-Path $tempFolder -ChildPath "Extract"
Unzip (Join-Path $tempFolder -childpath $PackageName) -outpath ($LocalDeploymentRoot)

$paramxmlfilepath=Join-Path $tempFolder -ChildPath "Extract\xml\Environments.xml"
#Changing environemnt to PROD for config issue on 18/10/20202 R33 PCORP
$ConfigProdEnvironment=$Environment
if($Environment -ieq "PCORP"){
	$ConfigProdEnvironment="PROD"
}
#Changing environemnt to PROD for config issue on 18/10/20202 R33 PCORP ==> use $ConfigProdEnvironment instead of $Environment
ConfigDeployer -ParameteXMLFile $paramxmlfilepath -Environment $ConfigProdEnvironment -DeploymentFolder $LocalDeploymentRoot 
#delete all ALTIRIS*.config, CITRIX*.config and *IsBroker*.config
$includeArray=@("ALTIRIS*.config", "CITRIX*.config", "*IsBroker*.config")
Get-ChildItem $LocalDeploymentRoot -Include $includeArray -Recurse | Remove-Item -Force

#rename some configs eg AICORP*.config
$configPrefix=[string]::Format("A{0}",$ConfigProdEnvironment)
Get-ChildItem $LocalDeploymentRoot -Include @([string]::Format("{0}*.config",$configPrefix)) -Recurse | ForEach-Object {
    $newConfigName=$_.Name.Substring($configPrefix.Length)
    Rename-Item -Path $_ -NewName $newConfigName
}

#rename some configs eg BICORP*.config
$configPrefix=[string]::Format("B{0}",$ConfigProdEnvironment)
Get-ChildItem $LocalDeploymentRoot -Include @([string]::Format("{0}*.config",$configPrefix)) -Recurse | ForEach-Object {
    $newConfigName=$_.Name.Substring($configPrefix.Length)
    Rename-Item -Path $_ -NewName $newConfigName
}

#rename BaseMercatorNetClient.config
$config="BaseMercatorNetClient.config"
Get-ChildItem $LocalDeploymentRoot -Include $config -Recurse | ForEach-Object {
    Rename-Item -Path $_ -NewName "MercatorNetClient.config"
}

Copy-Item (Join-Path $tempFolder -ChildPath "Extract\ClientFiles\Broker\0.0.0.0\*") -Destination $VersionZeroFolder -Recurse
Remove-Item $tempFolder -Recurse -force

#update msi name if Environment -ine "pcorp"
if ($Environment -ine "pcorp"){
    #regex for finding the msi name in the setup project (=vdproj)
    [Regex]$regex = "[\w*\-*\w*]*\.msi"
    #replace the msi name in vdproj files
    Get-ChildItem $TfsSourceFolder -Filter "*.vdproj" -Recurse | ForEach-Object {
        $msiName=(select-string -Path $_.FullName -Pattern $regex).Matches[0].Value
        $newMsiName=$Environment+"_"+$msiName
        ((Get-Content -path $_.FullName -Raw) -replace $msiName,$newMsiName) | Set-Content -Path $_.FullName
    }
}