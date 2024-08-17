# Enable -Verbose option
[CmdletBinding()]

param([String]$TfsSourceFolder,[String]$TfsStagingFolder,[String]$BuildID,$SearchPattern="*.config.deployment,*.xml.deployment,*.ps1.deployment,*.json.deployment",$dotnetCoreSolution=$false, $upload2Sweagle=$false)

if (!$TfsSourceFolder){
	$TfsSourceFolder = "E:\TFSBuild\154\s"
	$TfsStagingFolder = "E:\TFSBuild\154\a"
	$BuildID="Dev_DocumentTransformer_20210429.9"
	$VerbosePreference = "Continue"
	$dotnetCoreSolution=$true
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
Write-Host "TfsStagingFolder= $TfsStagingFolder"
Write-Host "BuildID= $BuildID"
Write-Host "upload2Sweagle= ""$upload2Sweagle"""
Write-Host "start copying to local package folder"

$BuildVersion = $BuildID.Split("_")[$BuildID.Split("_").Length - 1]
$BuildDefenitionname = $BuildID.Replace("_" + $BuildVersion , "")
$ApplicationName=$BuildID.Split("_")[1]
$applicationName = $BuildDefenitionname.Split("_")[$BuildDefenitionname.Split("_").Length - 1]
$LocalPackageFolder = Join-Path $global:LocalPackageRoot -ChildPath $BuildDefenitionname | Join-Path -ChildPath $BuildVersion
$SharedPackageFolder = Join-Path $global:NewPackageRoot -ChildPath ("$($ApplicationName)\$($BuildDefenitionname)")


if($dotnetCoreSolution){
    Write-host "`r`n####### This is a dotnet core solution, Exrtacting Publish folder from bin directory #######`r`n"
    Get-ChildItem $TfsStagingFolder  | where { $_.PSIsContainer} | foreach {
		$CurrentprojectName=$_.Name    
	    Write-Host "Project :"  $CurrentprojectName
        $currentstagingFolder = Join-Path $TfsStagingFolder -ChildPath $CurrentprojectName
        $currentSourceFolder = (Get-ChildItem  $TfsSourceFolder -filter $CurrentprojectName  -Force -Recurse | where { $_.PSIsContainer}| select -first 1).FullName
        $currentSourceFolder
        $publishfolder=(Get-ChildItem  $currentSourceFolder -filter "Publish"  -Force -Recurse).FullName
	
if($publishfolder){
			Write-Host "Publish Folder Path : "$publishfolder
			remove-item "$currentstagingFolder\*" -Force -recurse -ErrorAction SilentlyContinue
			Copy-Item "$publishfolder\*" -Destination $currentstagingFolder -Force -recurse
		}
		else {
			Write-Host "There is no Publish Folder ,this could be a SQL project"
		}
    }
}

#recreate $LocalPackageFolder folder
If(test-path $LocalPackageFolder) {
	Remove-Item -Path $LocalPackageFolder -Force -Recurse
}
New-Item -ItemType Directory -Force -Path $LocalPackageFolder | Out-Null

#create $SharedPackageFolder folder
If(!(test-path $SharedPackageFolder)) {
	New-Item -ItemType Directory -Force -Path $SharedPackageFolder | Out-Null
}

$SearchPattern=$SearchPattern.Split(',')
#$SearchPattern = @("*.config.deployment","*.xml.deployment","*.ps1.deployment","*.json.deployment")

Get-ChildItem $TfsStagingFolder  | where { $_.PSIsContainer} | foreach {
	Write-Host "copying $_.Name"
	$currentSourceFolder = Join-Path $TfsStagingFolder $_.Name
	if (Test-Path (Join-Path $currentSourceFolder "_PublishedWebsites") ){
		$currentSourceFolder = Join-Path $currentSourceFolder -ChildPath "_PublishedWebsites" | Join-Path -ChildPath $_.Name 
	}
	$dummy = New-Item (join-Path $LocalPackageFolder $_.Name) -type directory
	Copy-Item $currentSourceFolder\ -Destination $LocalPackageFolder -Force -Recurse 
	#Remove-Item $LocalPackageFolder -Include "*.config" -Exclude "config.deployment" -Recurse
}

#copy DeploymentManifest to package folder
$deployManifestFileName = $applicationName + "DeploymentManifest.xml"
Get-ChildItem $TfsSourceFolder -Recurse -Include  $deployManifestFileName | copy -Destination $LocalPackageFolder

#copy AfterBuildActions to package folder
$AfterBuildActionsFileName = $applicationName + "AfterBuildActions.xml"
Get-ChildItem $TfsSourceFolder -Recurse -Include  $AfterBuildActionsFileName | copy -Destination $LocalPackageFolder

#copy HealthCheckParameters file to package folder
$HealthCheckFileName = $applicationName + "HealthCheckParameters.xml"
$HealthCheckFileNameFile = "$LocalPackageFolder\$HealthCheckFileName"
Get-ChildItem $TfsSourceFolder -Recurse -Include  $HealthCheckFileName | copy -Destination $LocalPackageFolder

#copy parameterfile to package folder
$parameterFileName = $applicationName + "DeploymentParameters.xml"
$parameterFile = "$LocalPackageFolder\$parameterFileName"
Get-ChildItem $TfsSourceFolder -Recurse -Include  $parameterFileName | copy -Destination $LocalPackageFolder

Write-Host "start resolving $parameterFileName"
$scriptPath = [String]::Format("{0}\Build\ResolveParameterXml.ps1",  $ScriptDirectory )
#call the script
& $scriptPath -verbose $parameterFile -BuildVersion $BuildVersion

#loop all Environments in parameterfile and create config files for each environment
$parameterFileObject=Get-Item $parameterFile
$parameterFileResolved = [String]::Format("{0}\{1}_Resolved{2}", $parameterFileObject.DirectoryName, $parameterFileObject.BaseName, $parameterFileObject.Extension)
$parameters = [xml] (Get-Content $parameterFileResolved)
$scriptPath = [String]::Format("{0}\Build\CreateConfig4Environment.ps1",  $ScriptDirectory )
#$scriptPath = [String]::Format("C:\Users\ch02114\Desktop\CreateConfig4Environment.ps1")
$parameters.SelectNodes("//Parameters/EnvironmentParameters/Environment") | where {$_.NodeType -ne "Comment"} | foreach {
	$currentEnvironment = $_.Attributes.GetNamedItem("name").Value
	#run for all *.deployment files
	& $scriptPath -verbose -parameterFile $parameterFileResolved -environment $currentEnvironment -packageRootPath $LocalPackageFolder -SearchPattern $SearchPattern
	#run for deploymentManifest
	& $scriptPath -verbose -parameterFile $parameterFileResolved -environment $currentEnvironment -packageRootPath $LocalPackageFolder -SearchPattern $applicationName"DeploymentManifest.xml"
}

if ($upload2Sweagle){
    Upload2Sweagle -paramFileResolved $parameterFileResolved -Application $ApplicationName -Buildversion $BuildID -ScriptDir $ScriptDirectory
}

Copy-FolderWithNetUse -SourceFolder $LocalPackageFolder -DestinationRootFolder $SharedPackageFolder