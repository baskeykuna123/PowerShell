Param
(
	[ValidateSet("Mercator.Legacy.Back","Mercator.Legacy.Data","Mercator.Legacy.Eai","Mercator.Legacy.EaiDocService","Mercator.Legacy.Front")] 
        [String] $PackageType,
	[ValidateSet("ClassicFront","ClassicBack","EaiDocService")]
        [String] $ServerType
)
Clear-host

if (!$ServerType){
    $ServerType="ClassicBack"
    $PackageType="Mercator.Legacy.Back"   
}

$Action="Stop"

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

switch($ServerType)
{
    "ClassicFront" {
        $CommonConfigFolder=Join-Path $global:FrontLegacyRoot -ChildPath "Common" | Join-Path -ChildPath "Config"
    }
    "ClassicBack" {
        $CommonConfigFolder=Join-Path $global:BackofficeRoot -ChildPath "Common" | Join-Path -ChildPath "Config"
    }
    "EaiDocService" {
        $CommonConfigFolder=Join-Path $global:EaiDocServiceRoot -ChildPath "Common" | Join-Path -ChildPath "Config"
    }
    default {
    	Write-Host "ServerType not valid : " $PackageType
	    Exit 1
    }
}

switch($PackageType)
{
    "Mercator.Legacy.Back" {
        $DeploymentRoot=$global:BackofficeRoot
        $JunctionExeFolder=$GacUtilExeFolder=Join-Path $global:BackofficeRoot -ChildPath "Deployment" | Join-Path -ChildPath "Executables"
        $installutillExePath=Join-Path $global:BackofficeRoot -ChildPath "Deployment" | Join-Path -ChildPath "Executables" | Join-Path -ChildPath "InstallUtil.exe"
    }
    "Mercator.Legacy.Data" {
        $DeploymentRoot=$null
    }
    "Mercator.Legacy.Eai" {
        $DeploymentRoot=$global:BackofficeEaiRoot
        $JunctionExeFolder=$GacUtilExeFolder=Join-Path $global:BackofficeEaiRoot -ChildPath "InstallationUtilities" | Join-Path -ChildPath "Executables"
        $installutillExePath=Join-Path $global:BackofficeEaiRoot -ChildPath "InstallationUtilities" | Join-Path -ChildPath "Executables" | Join-Path -ChildPath "InstallUtil.exe"
    }
    "Mercator.Legacy.EaiDocService" {
        $DeploymentRoot=$global:EaiDocServiceRoot
        $JunctionExeFolder=$GacUtilExeFolder=Join-Path $global:EaiDocServiceRoot -ChildPath "InstallationUtilities" | Join-Path -ChildPath "Executables"
        $installutillExePath=Join-Path $global:EaiDocServiceRoot -ChildPath "InstallationUtilities" | Join-Path -ChildPath "Executables" | Join-Path -ChildPath "InstallUtil.exe"
    }
    "Mercator.Legacy.Front" {
        $DeploymentRoot=$global:FrontLegacyRoot
        $JunctionExeFolder=$GacUtilExeFolder=Join-Path $global:FrontLegacyRoot -ChildPath "Deployment" | Join-Path -ChildPath "Executables"
        $installutillExePath=Join-Path $global:FrontLegacyRoot -ChildPath "Deployment" | Join-Path -ChildPath "Executables" | Join-Path -ChildPath "InstallUtil.exe"
    }
    default {
    	Write-Host "PackageType not valid : " $PackageType
	    Exit 1
    }
}

$Rootlogfolder=[String]::Format("{0}\Logs\{1}_{2}",$DeploymentRoot, $Action, (Get-Date -Format yyyyMMdd-hhmmss))

# Reading the Master Deploy Sequence
$DeploymentxmlDirectory=join-path $DeploymentRoot -ChildPath "XML"
$MasterDeploySequencePath=join-path $DeploymentxmlDirectory  -ChildPath ($PackageType + ".Master.DeploySequence.xml")

Write-Host "=============================================================================="
Write-Host "Package Folder             :"$PackageFolder
Write-Host "Master Deploy Sequence Path:"$MasterDeploySequencePath
Write-Host "Deployment XML directory   :"$DeploymentxmlDirectory
Write-Host "=============================================================================="

if (! (Test-Path $MasterDeploySequencePath ) ){
    #MasterDeploySequence does not exist. This means that there is nothing installed. Exit script, but without error code
    Write-Host "MasterDeploySequence - $MasterDeploySequencePath - not found.."
    exit
}

$MasterDeployXML=[xml](get-content filesystem::$MasterDeploySequencePath -Force )

$DeploySequencelist=$MasterDeployXML.'Master.DeploySequence'.'DeployPackages.DeploySequence'.DeployPackage 
#$DeploySequencelist="Mercator.Legacy.Common.AD.ComPlus.DeploySequence.xml"

$overallDeployStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.status
if ($overallDeployStatus -ne "UnInstalling"){
	if ($overallDeployStatus -eq "Stopped")  {
		Write-Host "Already stopped."		
		Exit
	} 
	elseif ([string]::IsNullOrEmpty($overallDeployStatus) -or ($overallDeployStatus -ieq "Deploying") -or ($overallDeployStatus -ieq "Starting") ) {
		Write-Host "Previous deployment not finished. Abort Stop script."
		Exit
	}
	else {
		SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "Stopping"
	}
}

#reversing the application list while stopping
#no need to reverse for MyBaloiseClassic + COM+ has to be stopped before some services can be stopped
#if ($Action -ieq "Stop"){
#    [array]::Reverse($DeploySequencelist)
#}

foreach($DeploySequenceXML in $DeploySequencelist){
    
    $DeploySequenceXMLInnerText=$DeploySequenceXML.name
	$DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
	Write-Host "Deploy Sequence Name:"$DeploySequenceName
	$ApplicationDeploySequenceFile=[String]::Format("{0}\{1}",$DeploymentxmlDirectory,$DeploySequenceXMLInnerText)	

    $masterXPpath=[string]::Format("//DeployPackage[@name='{0}']",$DeploySequenceXMLInnerText)
    $DeployPackageNode=$MasterDeployXML.SelectSingleNode($masterXPpath)
    $CurrenApplicationDeployStatus=$DeployPackageNode.status
    if ([string]::IsNullOrEmpty($CurrenApplicationDeployStatus) -or ($CurrenApplicationDeployStatus -ne "Stopped")){
        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "Stopping"

	    #Loading All XML Sections
	    $DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
	    $ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
	    #clear all XML varibales
	    $GACAssemblies=$null

	    if($ApplicationConfiguration.ChildNodes){

		    #$unInstalllogfolder=Join-Path $Rootlogfolder -ChildPath $DeploySequenceName


            if($ApplicationConfiguration.ComPlusComponents){
                $ApplicationConfiguration.ComPlusComponents.ComPlusComponent | ForEach-Object{
                    Stop-ComPlus -targetApplication $_.ComPlusName 
                }
            }

            if ($ApplicationConfiguration.NTServices){
                $ApplicationConfiguration.NTServices.NTService | ForEach-Object{
                    Stop-WindowsService -serviceName $_.NTServiceName.InnerText
                }
            }

	    }
		
		SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "Stopped"
        Write-Host "============================================================================================`n"
    }
    else {
        Write-Host "$DeploySequenceName was already Stopped."
    }
}

##stop ok, update 
SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "Stopped"
Write-Host "===================================  $([io.path]::GetFileNameWithoutExtension($MasterDeploySequencePath))  -  End $($Action)  ========================================================="