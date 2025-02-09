Param
(
[String]$ServerType,
[String]$Platform,
[String]$Environment
)
Clear-host

if(!$ServerType){
	$ServerType = "admin"
    $Platform="Eai"
}
# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$ErrorActionPreference='Stop'

#Getting MasterDeploy Sequence
$DeploymentxmlDirectory=join-path $global:ESBRootFolder -ChildPath "$Platform\XML"
Write-Host "Environment:"$Environment
Write-Host "`nDeployment Directory:"$DeploymentxmlDirectory
Write-Host "`n"

if ($Platform -eq "Esb"){
	$MasterDeploySequencePath=join-path $DeploymentxmlDirectory  "Mercator.Esb.Master.DeploySequence.xml"
}
elseif ($Platform -eq "Eai"){
	$MasterDeploySequencePath=Join-Path $DeploymentxmlDirectory "Mercator.Esb.Eai.Master.DeploySequence.xml"
}
else{
	throw "Platform not known."
}

if (! (Test-Path $MasterDeploySequencePath ) ){
    #MasterDeploySequence does not exist. This means that there is nothing installed. Exit script, but without error code
    Write-Host "MasterDeploySequence - $MasterDeploySequencePath - not found.."
    exit
}

$paramxmlfilepath=Join-Path $global:ESBRootFolder -ChildPath "$Platform\ESBDeploymentParameters_Resolved.xml"	
$MasterDeployXML=[xml] (get-content filesystem::$MasterDeploySequencePath -Force )
$DeploySequencelist=$MasterDeployXML.'Master.DeploySequence'.'DeployPackages.DeploySequence'.DeployPackage 
#$DeploySequencelist="Mercator.Esb.Framework.DeploySequence.xml"
$ReadResolvedDeploymentParametersXMLFile =[XML](Gc $paramxmlfilepath)

# Read attribute for ApplicationToExclude
$ExcludedAplicationList=$ReadResolvedDeploymentParametersXMLFile.SelectNodes("//Parameters/EnvironmentParameters/Environment[@name='$Environment']/add[@key='ApplicationToExclude']").value

$ListofDeploySequences=@()
Foreach($deploysequencename in $DeploySequencelist){
    $ApplicationName=$deploysequencename -ireplace ".DeploySequence.xml",""
    if($ExcludedAplicationList -inotlike "*$ApplicationName*"){
        $ListofDeploySequences+=$deploysequencename
    }
}
$DeploySequencelist=$ListofDeploySequences

$ESBDeploymentFolder=[String]::Format("{0}{1}\",$global:ESBRootFolder,$Platform)
$Rootlogfolder=[String]::Format("{0}\Logs\Uninstall_{1}",$ESBDeploymentFolder,(Get-Date -Format "yyyyMMdd-hhmmss"))

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
    
    if ($DeploySequenceXML.Attributes.Count -eq 0){
        $DeploySequenceXMLInnerText=$DeploySequenceXML
    }
    else{
        $DeploySequenceXMLInnerText=$DeploySequenceXML.InnerText
    }

	$DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
	Write-Host "Deploy Sequence Name:"$DeploySequenceName
	$ApplicationDeploySequenceFile=[String]::Format("{0}\XML\{1}",$ESBDeploymentFolder,$DeploySequenceXMLInnerText)	

    $masterXPpath=[string]::Format("//DeployPackage[text()=""{0}""]",$DeploySequenceXMLInnerText)
    $DeployPackageNode=$MasterDeployXML.SelectSingleNode($masterXPpath)
    $CurrenApplicationDeployStatus=$DeployPackageNode.status
    if ([string]::IsNullOrEmpty($CurrenApplicationDeployStatus) -or ($CurrenApplicationDeployStatus -ne "UnInstalled")){
        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "UnInstalling"

	    #Loading All XML Sections
	    $DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
		
		# Uninstalling scheduled task
		$ScheduledTasks=$DeploySequenceReader.SelectNodes("//Package.DeploySequence/SystemConfiguration/ScheduledTasks")        
        If($ScheduledTasks.ChildNodes){
            If($($ScheduledTasks.status) -ine "Uninstalled"){
                $TaskName=$($ScheduledTasks.ScheduledTask.name)
                UnregisterScheduledTask -TaskName $TaskName
                AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement "Package.DeploySequence/SystemConfiguration/ScheduledTasks" -NewAttribute "Status" -NewAttributeValue "Uninstalled"
            }
        }
		ElseIf($($ScheduledTasks.status) -ieq "Uninstalled"){
			Write-Host "Task $TaskName is already Uninstalled..!"
		}		
		
	    $ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
	    #clear all XML varibales
	    $GACAssemblies=$null

	    #getting the Biztalk Application Info
	    if($ApplicationConfiguration.ChildNodes){

		    $BiztalkApplications=$ApplicationConfiguration.BizTalkApplications.BizTalkApplication
		    if($ApplicationConfiguration.GacAssemblies.ChildNodes){
			    $GACAssemblies=$ApplicationConfiguration.SelectNodes("//GacAssemblies/Assembly/AssemblyName")
			}
			
			if($ApplicationConfiguration.ReferencedAssemblies.ChildNodes){
			    $GACAssemblies+=$ApplicationConfiguration.SelectNodes("//ReferencedAssemblies/Assembly/AssemblyName")
		    }

            if($BiztalkApplications.ChildNodes){
			    #add assemblies pipeline assemblies and GAC assembliesto GACAssemblies
			    $GACAssemblies+=$BiztalkApplications.selectNodes("//BizTalkResource//BizTalkResourceName")
			    $GACAssemblies += $ApplicationConfiguration.SelectNodes("//PipelineComponents/PipelineComponent/PipelineComponentName")
            }

		    Write-Host "===================================APPLICATION CONFIGURATION========================================================="
		    # Derive application to point deployment root folder of ESB.
		    $unInstalllogfolder=Join-Path $Rootlogfolder -ChildPath $DeploySequenceName
		
		    # Uninstall Applications if servertype = "admin"
		    if( ($ServerType -eq "Admin") -and $BiztalkApplications ){
				$RootXPath="//BizTalkApplications/BizTalkApplication"
				$Application=$BiztalkApplications.BizTalkApplicationName
				#get DeploymentStarted flag
				$overallDeployStatus=$ApplicationConfiguration.SelectSingleNode("$RootXPath").overallStatus
				if ($overallDeployStatus -ne "ApplicationRemoved"){				
					Write-Host "`n--- *** REMOVE APPLICATION *** ---"
					SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath  -Attribute "overallStatus" -NewAttributeValue "ApplicationRemoveStarted"

					$UnInstallFolder=[String]::Format("{0}\UninstallApplication_Log.txt",$unInstalllogfolder)
					New-Item $UnInstallFolder -ItemType File -Force | Out-Null 
					$createApplicationStatus=$ApplicationConfiguration.SelectSingleNode("$RootXPath").createApplicationStatus
					#if ($createApplicationStatus -ne "ApplicationStopped"){
					#	Stop-BTSApplication $Application | Add-Content -Path $UnInstallFolder
					#	SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath  -Attribute "createApplicationStatus" -NewAttributeValue "ApplicationStopped"
					#} 
					
					Remove-BTSApplication $Application | Add-Content -Path $UnInstallFolder
                    #update status in ApplicationDeploySequence
					SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath  -Attribute "createApplicationStatus" -NewAttributeValue "ApplicationRemoved"
					SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath  -Attribute "overallStatus" -NewAttributeValue "ApplicationRemoved"
                    #update status in MasterDeploySequence
                    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "statusBtsApplication" -NewAttributeValue "Removed"
				}
				else{
					Write-Host "$Application already removed."
				}
	 		}
		
		    # Remove  Assemblies to GAC
		    $UnInstallFolder=[String]::Format("{0}\RemoveGAC_Log.txt",$unInstalllogfolder)
		    New-Item $UnInstallFolder -ItemType File -Force | Out-Null
		
			if($GACAssemblies){
		    	Write-Host "--- *** REMOVE GAC *** ---"
		    	ForEach($AssemblyName in $($GACAssemblies.innerText)){
				    if($AssemblyName -inotlike "Microsoft*")
					{
						Remove-GAC  -AssemblyName $AssemblyName -LogFile $UnInstallFolder   #| Add-Content -Path $UnInstallFolder -Force
					}
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
	# CDM Backup
	$CdmBackupFolder="E:\Cdm_Backup"
	New-Item $CdmBackupFolder -ItemType Directory -Force | Out-Null
	$PortalCDMFolder=[String]::Format("{0}Portal\Content\Cdm",$ESBDeploymentFolder)
	if(Test-Path $PortalCDMFolder){
		copy "$PortalCDMFolder\*" -Destination "$CdmBackupFolder\" -Force -Recurse
	}
	
	# BACKUP - FUNCTIONAL DESIGN FOLDER
	$FunctionalDesignBackupFolder="E:\Backup\FuntionalDesign_Backup"
	$FunctionalDesignFolder=[String]::Format("{0}\Portal\Content\FunctionalDesign",$ESBDeploymentFolder)

	if($(Test-Path $FunctionalDesignFolder)){
	    New-Item $FunctionalDesignBackupFolder -ItemType Directory -Force | Out-Null
	    Copy-Item "$FunctionalDesignFolder\*" -Destination "$FunctionalDesignBackupFolder\" -Force -recurse
	}
	Else{
	    Write-Host "INFO: Functional design folder does not exist under portal\Content\"
	}
	
    # Backup
    $BackupFolder=[String]::Format("E:\Backup\Backup-{0}_{1}\",$Platform, (Get-Date -Format "yyyyMMdd-hhmmss"))
    New-Item $BackupFolder -ItemType Directory -Force | Out-Null
    Write-Host "BACKUP: Processing..."
    Copy-Item "$ESBDeploymentFolder\*" -destination $BackupFolder -Force -Recurse -ErrorAction Stop
	Write-Host "BACKUP: Completed."
	
    # Delete DeploymentFolder
	Write-Host "REMOVE $($Platform.ToUpper()) FOLDER: Processing... "
    Remove-Item $ESBDeploymentFolder -Force -Recurse -ErrorAction Stop
	Write-Host "REMOVE $($Platform.ToUpper()) FOLDER: Completed."
	
	# Check Deployment root folder to make sure all are gone
	$DeployStatusXML=Join-Path $ESBDeploymentFolder -ChildPath "DeployStatus.xml"
	if((Test-Path $DeployStatusXML) -eq $true){
		Remove-Item $DeployStatusXML -Force -ErrorAction Stop
	}	
	
	#uninstall succeeded ==> update status
	#SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "UnInstalled"
}
catch{
    throw $_
}