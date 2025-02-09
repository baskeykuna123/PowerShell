Param
(
	[ValidateSet("Mercator.Legacy.Client","Mercator.DMS.IPClient","Mercator.DMS.Brandkast")] 
        [String] $PackageType,
	[ValidateSet("ClassicBack")]
        [String] $ServerType,
	[String]$Environment,
    [String]$BuildVersion
)
Clear-host

if (!$ServerType){
    $ServerType="ClassicBack"
    $Environment="Dcorp"
    $PackageType="Mercator.DMS.Brandkast"
    $BuildVersion="35.7.20210210.191613"
}

write-host $ServerType
write-host $Environment
write-host $PackageType
write-host $BuildVersion

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

if ([string]::IsNullOrEmpty($BuildVersion)){
	throw "BuildVersion not set."
}
Write-Host "BuildVersion:"$BuildVersion

#Getting the Package to be Deployed
$PackageZip = [String]::Format("$global:MBCPackageRoot\{0}\{1}.zip",$BuildVersion, $PackageType)

if(-not (Test-Path $PackageZip)){
	Write-Host "Package Not found : " $PackageZip
	Exit 1
}

switch($ServerType)
{

    "ClassicBack" {
        $CommonConfigFolder=Join-Path $global:BackofficeRoot -ChildPath "Common" | Join-Path -ChildPath "Config"
        $LocalDeploymentRoot=Join-Path $global:LocalMBCWorkFolder -ChildPath $BuildVersion
    }
    default {
    	Write-Host "ServerType not valid : " $PackageType
	    Exit 1
    }
}

$CitrixChildPath="$Environment-Current-RZ3"
if($Environment -ieq "PreProd"){
	$CitrixChildPath="PreProd"
} 

switch($PackageType)
{
    "Mercator.Legacy.Client" { 
        $DeploymentRoot=Join-Path $global:AppShareRoot -ChildPath $Environment| Join-Path -ChildPath $Global:ClientImageSubPath
        #$CitrixDeploymentRoot=Join-Path $global:MBCCitrixClientSourcePath -ChildPath "$Environment-Current-RZ3"
        $CitrixDeploymentRoot=Join-Path $global:MBCCitrixClientSourcePath -ChildPath $CitrixChildPath
        $ClientFilesDirectory=join-path $LocalDeploymentRoot -ChildPath "ClientFiles"
        $ClientFilesSource4Citrix=join-path $ClientFilesDirectory -ChildPath "Internal" | Join-Path -ChildPath $BuildVersion
    }
    "Mercator.DMS.IPClient" { 
        $DeploymentRoot=$null
        #$CitrixDeploymentRoot=Join-Path $global:DMSCitrixClientSourcePath -ChildPath "$Environment-Current-RZ3"
        $CitrixDeploymentRoot=Join-Path $global:DMSCitrixClientSourcePath -ChildPath $CitrixChildPath
        $ClientFilesDirectory=join-path $LocalDeploymentRoot -ChildPath "ClientFiles"
        $ClientFilesSource4Citrix=$ClientFilesDirectory
    }
    "Mercator.DMS.Brandkast" { 
        $DeploymentRoot=$null
        #$CitrixDeploymentRoot=Join-Path $global:DMSCitrixBrandkastSourcePath -ChildPath "$($Environment)_Current"
        $CitrixDeploymentRoot=Join-Path $global:DMSCitrixBrandkastSourcePath $CitrixChildPath
        $ClientFilesDirectory=join-path $LocalDeploymentRoot -ChildPath "ClientFiles"
        $ClientFilesSource4Citrix=join-path $ClientFilesDirectory -ChildPath "MulticompanyBrandkast"
    }
    default {
    	Write-Host "PackageType not valid : " $PackageType
	    Exit 1
    }
}

$Rootlogfolder=[String]::Format("{0}\Logs\Install_{1}",$LocalDeploymentRoot,(Get-Date -Format yyyyMMdd-hhmmss))
$DeployStatusFile=Join-Path $LocalDeploymentRoot -ChildPath "DeployStatus.xml"

if (Test-Path $DeployStatusFile){
	Write-Host "DeployStatus.xml found."
}
else{
    CreateDeployStatusXML $LocalDeploymentRoot
}
$DeployStatusXML=[xml](get-content filesystem::$DeployStatusFile -Force )

#Copy the Package on the server
if ($DeployStatusXML.DeployStatus.DeployPackage.status -ne "Succeeded"){
    Write-Host "Copying zip : " $PackageZip
    $WorkingFolder=Join-Path $LocalDeploymentRoot -ChildPath ($PackageType + ".Work")
    New-Item $WorkingFolder -ItemType Directory  -Force| Out-Null
    #copy zip to working folder
    Copy-Item $PackageZip -destination $WorkingFolder -Force -Recurse
    $LocalZip = [String]::Format("$WorkingFolder\{0}.zip", $PackageType)
    #unzip to working folder
    Unzip -zipfile $LocalZip -outpath (Join-Path $WorkingFolder -ChildPath "unzip")

    #copy all folders from unzip folder to deployment root
    #first delete existing folders in deployment root
    Get-ChildItem (Join-Path $WorkingFolder -ChildPath "unzip") | Where-Object {$_.PSIsContainer } | ForEach-Object {
        if (Test-Path -Path (Join-Path $LocalDeploymentRoot -ChildPath $_.Name)){
            Remove-Item (Join-Path $LocalDeploymentRoot -ChildPath $_.Name) -Force -Recurse
        }

        Copy-Item $_.FullName -Destination (Join-Path $LocalDeploymentRoot -ChildPath $_.Name) -Force -Recurse
    }

    #all went well, delete work folder
    Remove-Item $WorkingFolder -Force -Recurse

    #add succeeded to DeployStatusXML
    AddElementWithAttributeToXml -XmlPath $DeployStatusFile -ParentElement "DeployStatus" -NewElementName "DeployPackage" -NewAttribute "status" -NewAttributeValue "Succeeded"
}
else{
    Write-Host "Package : " $BuildVersion " was already copied."
}

#Setting the Configuration based on the environment
Write-Host "Environment:"$Environment
if ($DeployStatusXML.DeployStatus.DeployConfig.status -ne "Succeeded"){
    $paramxmlfilepath=Join-Path $LocalDeploymentRoot -ChildPath "xml\Environments.xml"
    #Changing environemnt to PROD for config issue on 18/10/20202 R33 PCORP
    $ConfigProdEnvironment=$Environment
    if($Environment -ieq "PCORP" -or $Environment -ieq "PREPROD"){
	    $ConfigProdEnvironment="PROD"
    }
    #Changing environemnt to PROD for config issue on 18/10/20202 R33 PCORP ==> use $ConfigProdEnvironment instead of $Environment
    ConfigDeployer -ParameteXMLFile $paramxmlfilepath -Environment $ConfigProdEnvironment -DeploymentFolder $LocalDeploymentRoot 
    #delete all ALTIRIS*.config, BROKERSMINI*.config, CITRIX*.config and *IsBroker*.config
    $includeArray=@("ALTIRIS*.config", "BROKERSMINI*.config", "CITRIX*.config", "*IsBroker*.config")
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

    #add succeeded to DeployStatusXML
    AddElementWithAttributeToXml -XmlPath $DeployStatusFile -ParentElement "DeployStatus" -NewElementName "DeployConfig" -NewAttribute "status" -NewAttributeValue "Succeeded"
}
else{
    Write-Host "Configuration was already deployed."
}

# Reading the Master Deploy Sequence
$DeploymentxmlDirectory=join-path $LocalDeploymentRoot -ChildPath "XML"

# Check attribute type of files and remove all ReadOnly attributes of Deploysequence XMLs
Gci -Path $DeploymentxmlDirectory -Recurse | ?{-not $_.PSIsContainer -and $_.IsReadOnly} |
ForEach-Object {
	Try{
		$_.IsReadOnly = $false
	}
	Catch{
		Write-Warning $_.exception.message
	}
}	


#$BuildOutputPath="\\svw-be-bldp001\E$\P.ESB"
$MasterDeploySequencePath=join-path $DeploymentxmlDirectory  -ChildPath ($PackageType + ".Master.DeploySequence.xml")
$MasterDeployXML=[xml](get-content filesystem::$MasterDeploySequencePath -Force )

Write-Host "=============================================================================="
Write-Host "Build Version              :"$BuildVersion
Write-Host "Package Folder             :"$PackageFolder
Write-Host "Master Deploy Sequence Path:"$MasterDeploySequencePath
Write-Host "Deployment XML directory   :"$DeploymentxmlDirectory
Write-Host "=============================================================================="

$overallDeployStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.status
if ([string]::IsNullOrEmpty($overallDeployStatus)){
    AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -NewAttribute "status" -NewAttributeValue "Deploying"
}
elseif ($overallDeployStatus -eq "Deployed"){
    Write-Host "Deployment already done."
    Exit
}

#copy folders to dfs share
if($DeploymentRoot -and ($Environment -ine "PreProd") ){
    $DeploymentRoot = $DeploymentRoot.TrimEnd("\\")
    Copy-FolderWithNetUse -SourceFolder $ClientFilesDirectory -DestinationRootFolder $DeploymentRoot -CleanDestinationBeforeCopy $false
}

Copy-FolderWithPSDrive -SourceFolder $ClientFilesSource4Citrix -DestinationRootFolder $CitrixDeploymentRoot -Copy2Root $false

#deployment ok, update 
SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "Deployed"
Write-Host "===================================  $([io.path]::GetFileNameWithoutExtension($MasterDeploySequencePath))  -  End Installation  ========================================================="

Remove-Item $LocalDeploymentRoot -Recurse -Force