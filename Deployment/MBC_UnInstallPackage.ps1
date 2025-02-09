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

write-host $ServerType
write-host $PackageType

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
    	Write-Host "ServerType not valid : " $ServerType
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

$Rootlogfolder=[String]::Format("{0}\Logs\UnInstall_{1}",$DeploymentRoot,(Get-Date -Format yyyyMMdd-hhmmss))

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
#$DeploySequencelist="Mercator.Esb.Framework.DeploySequence.xml"

$overallDeployStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.status
if ($overallDeployStatus -ne "UnInstalling"){
	if ($overallDeployStatus -eq "UnInstalled")  {
		Write-Host "UnInstall already done."		
		Exit
	} 
	elseif ([string]::IsNullOrEmpty($overallDeployStatus) -or ($overallDeployStatus -ieq "Deploying") -or ($overallDeployStatus -ieq "Starting") ) {
		Write-Host "Previous deployment not finished. Abort UnInstall script."
		Exit
	}
	else {
		SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "UnInstalling"
	}
}

#reversing the application list while uninstalling
[array]::Reverse($DeploySequencelist)
foreach($DeploySequenceXML in $DeploySequencelist){
    
    $DeploySequenceXMLInnerText=$DeploySequenceXML.name
	$DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
    $currentServerType=$DeploySequenceXML.serverType
	Write-Host "Deploy Sequence Name:"$DeploySequenceName
	$ApplicationDeploySequenceFile=[String]::Format("{0}\{1}",$DeploymentxmlDirectory,$DeploySequenceXMLInnerText)	

    $masterXPpath=[string]::Format("//DeployPackage[@name='{0}']",$DeploySequenceXMLInnerText)
    $DeployPackageNode=$MasterDeployXML.SelectSingleNode($masterXPpath)
    $CurrenApplicationDeployStatus=$DeployPackageNode.status
    if ([string]::IsNullOrEmpty($CurrenApplicationDeployStatus) -or ($CurrenApplicationDeployStatus -ne "UnInstalled")){
        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "UnInstalling"

	    #Loading All XML Sections
	    $DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
	    $ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
	    #clear all XML varibales
	    $GACAssemblies=$null

	    if($ApplicationConfiguration.ChildNodes){

		    Write-Host "===================================APPLICATION CONFIGURATION========================================================="
		    # Derive application to point deployment root folder of ESB.
		    $unInstalllogfolder=Join-Path $Rootlogfolder -ChildPath $DeploySequenceName
		
		    # Remove  Assemblies to GAC
		    $UnInstallFolder=[String]::Format("{0}\RemoveGAC_Log.txt",$unInstalllogfolder)
		    New-Item $UnInstallFolder -ItemType File -Force | Out-Null

            if($ApplicationConfiguration.ComPlusComponents){
                $ApplicationConfiguration.ComPlusComponents.ComPlusComponent | ForEach-Object{
                    Remove-ComPlus -targetApplication $_.ComPlusName
                }
            }

            #getting Config Files for deleting the junctions
            $RootXPath="//ConfigFiles"
		    $ConfigFiles=$ApplicationConfiguration.SelectNodes("$RootXPath/ConfigFile")
		    if($ConfigFiles.ChildNodes){
                #get Deploying flag
                $CurrenDeployStatus=$ApplicationConfiguration.SelectSingleNode("$RootXPath/DeployStatus").status
                if ([string]::IsNullOrEmpty($CurrenDeployStatus) -or ($CurrenDeployStatus -ne "UnInstalled")){
                    #set UnInstalling flag
                    #AddElementDeploymentStarted -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
                    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "UnInstalling"
                    $ConfigLogFile=[String]::Format("{0}\UnDeployConfig_Log.txt",$unInstalllogfolder)
                    New-Item $ConfigLogFile -ItemType File -Force | Out-Null
	                Write-Host "`n --CONFIG UnDEPLOYMENT --"	
	                foreach($ConfigFile in $ConfigFiles){
	                    $ConfigFileName=$ConfigFile.name
	                    $ConfigJunctionSubdir=$ConfigFile.JunctionSubDirectory
                        $ConfigDestination=$ConfigFile.Destination -ireplace "%serverType%", $currentServerType
                        $configRootFolder=join-path $DeploymentRoot -ChildPath $ConfigDestination

	                    if($ConfigJunctionSubdir -ieq "Config"){
	                        $JunctionDestination= Join-Path $configRootFolder -ChildPath "config"
                            DeleteFolderJunction -JunctionDestination $JunctionDestination -LogPath $ConfigLogFile -InstallUtilitiesPath $JunctionExeFolder
	                    }

                    }
                    #set Deployed flag
                    SetElementDeploymentSucceeded -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
                }
                else{
                    Write-Host "`n --CONFIG DEPLOYMENT already done--"	
		        }
	        }


            if ($ApplicationConfiguration.NTServices){
                $ApplicationConfiguration.NTServices.NTService | ForEach-Object{
                    Delete-WindowsService -serviceName $_.NTServiceName.InnerText
                }
            }

            # Remove  Assemblies to GAC
		    $UnInstallFolder=[String]::Format("{0}\RemoveGAC_Log.txt",$unInstalllogfolder)
		    New-Item $UnInstallFolder -ItemType File -Force | Out-Null
            if($ApplicationConfiguration.GacAssemblies){
			    $ApplicationConfiguration.GacAssemblies.Assembly | ForEach-Object{
                    Remove-GAC  -AssemblyName $_.name -LogFile $UnInstallFolder -GacUtilPath $GacUtilExeFolder   #| Add-Content -Path $UnInstallFolder -Force
                }
			}
	    }
		
		SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "UnInstalled"
        Write-Host "============================================================================================`n"
    }
    else {
        Write-Host "$DeploySequenceName was already UnInstalled."
    }
}

#backup and delete Deployment folder
try{	
    # Backup
    $BackupFolder=[String]::Format("E:\Backup\Backup-{0}_{1}\",$PackageType, (Get-Date -Format "yyyyMMdd-hhmmss"))
    New-Item $BackupFolder -ItemType Directory -Force | Out-Null
    Write-Host "BACKUP: Processing..."
    Copy-Item "$DeploymentRoot\*" -destination $BackupFolder -Force -Recurse -ErrorAction Stop
	Write-Host "BACKUP: Completed."
	
    # Delete DeploymentFolder
    $exCeptionFolders=@("Deployment","Eai","InstallationUtilities","InstallUtilities","Common","Management")
	Write-Host "Removing $($PackageType) ..."
    Get-ChildItem $DeploymentRoot | ForEach-Object{
        $currentFolder=$_
        $retryCount=0
        if ($exCeptionFolders -inotcontains $currentFolder.Name){
            while ($retryCount -ile 5){
                try{
                    Remove-Item $currentFolder.FullName -Force -Recurse -ErrorAction Stop
                    break
                }catch{
                    $retryCount++
                    start-sleep -Seconds 5
                }
            }
        }
    }
	if (Test-Path -Path $DeploymentRoot"\Common" -PathType Container ){
        Remove-Item $DeploymentRoot"\Common" -Force -Recurse -ErrorAction Stop
    }
	Write-Host "Remove $($PackageType) Completed."
	
	# Check Deployment root folder to make sure all are gone
	$DeployStatusXML=Join-Path $DeploymentRoot -ChildPath "DeployStatus.xml"
	if((Test-Path $DeployStatusXML) -eq $true){
		Remove-Item $DeployStatusXML -Force -ErrorAction Stop
	}	
}
catch{
    throw $_
}