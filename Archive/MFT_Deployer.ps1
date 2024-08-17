param
(
[String]$Environment,
[String]$BuildVersion
)

# LOADING FUNCTION
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

if ([string]::IsNullOrEmpty($BuildVersion)){
	throw "BuildVersion not set."
}
Write-Host "BuildVersion:"$BuildVersion

$ApplicationFolders="Mercator.Framework.EsbCore","Services.Mft","CertificateStore"
$XMLFileSearchFilters="*.Esb.Master.DeploySequence.xml","*.Framework.EsbCore.DeploySequence.xml","*.Esb.Services.Mft.DeploySequence.xml","*.MftDeploymentManifest.xml"
$DeploySequencelist="Mercator.Framework.EsbCore.DeploySequence.xml","Mercator.Esb.Services.Mft.DeploySequence.xml"
$PackageFolder= [String]::Format("$global:NewPackageRoot\ESB\{0}",$BuildVersion)
$BackupFolder=[String]::Format("E:\Backup\{0}",$(Get-Date -Format yyyyMMdd-hhmmss))
$ESBDeploymentFolder=Join-Path $global:ESBRootFolder -ChildPath "ESB"
$XMLPackageRoot=[String]::Format("{0}\XML",$ESBDeploymentFolder)

if(-not (Test-Path $PackageFolder)){
	Write-Host "Package Not found : " $PackageFolder
	Exit 1
}

# BACKUP ESB DEPLOYMENT FOLDER
New-Item $BackupFolder -ItemType Directory -Force | Out-Null
Write-Host "BACKUP: Processing..."
Copy-Item "$ESBDeploymentFolder\*" -destination $BackupFolder -Force -Recurse -ErrorAction Stop
Write-Host "BACKUP: Completed."

# STOP MFT SERVICE
Stop-WindowsService -serviceName "ManagedFileTransfer"

# DELETE ESB DEPLOYMENT FOLDER 
Write-Host "REMOVE ESB FOLDER: Processing... "
Remove-Item $ESBDeploymentFolder -Force -Recurse -ErrorAction Stop
Write-Host "REMOVE ESB FOLDER: Completed."

New-Item $ESBDeploymentFolder -ItemType Directory  -Force| Out-Null
New-Item $XMLPackageRoot -ItemType Directory  -Force| Out-Null

#COPY THE PACKAGE ON THE SERVER
Write-Host "Copying Package : " $BuildVersion

ForEach($folder in $ApplicationFolders){
	$(gci $PackageFolder -Filter "$folder").FullName | Copy-Item -Destination $ESBDeploymentFolder -recurse -Force
}
ForEach($filter in $XMLFileSearchFilters)
{
	$(gci "$PackageFolder\XML" -File -Filter "$filter").FullName | %{Copy-Item $_ -Destination $XMLPackageRoot  -Force}
}
$(gci $PackageFolder -File -Filter "*.xml").FullName  | %{Copy-Item $_ -Destination $ESBDeploymentFolder -Force}

# SETTING THE CONFIGURATION BASED ON THE ENVIRONMENT
Write-Host "Environment:"$Environment

$paramxmlfilepath=Join-Path $ESBDeploymentFolder -ChildPath "ESBDeploymentParameters_Resolved.xml"
ConfigDeployer -ParameteXMLFile $paramxmlfilepath -Environment $Environment -DeploymentFolder $ESBDeploymentFolder

# READING THE MASTER DEPLOY SEQUENCE 
$MasterDeploySequencePath=join-path $XMLPackageRoot  "Mercator.Esb.Master.DeploySequence.xml"
$MasterDeployXML=[xml](get-content filesystem::$MasterDeploySequencePath -Force )     
 $PreRequisiteName=$MasterDeployXML.'Master.DeploySequence'.Prerequisites.Prerequisite
 
# SYSTEM VARIABLE
$SystemVariables=$PreRequisiteName.SystemVariables.SystemVariable
Write-Host "`n -- ADDING ENVIRONMENT VARIABLES --"
ForEach($Variable in $SystemVariables){
    Write-Host "Variable Name :"$Variable.name
    Write-Host "Variable Value:"$Variable.value
    if(![Environment]::GetEnvironmentVariable($($Variable.name),"Machine")){
	    [Environment]::SetEnvironmentVariable($($Variable.name),$($Variable.value),"Machine")
		if($LastExitCode -ne 0){
			throw "FAILED:Something went wrong while creating system variables"
		}
    }
}


# CERTIFICATE STORE
if($($PreRequisiteName.Certificate).ChildNodes){
	$CertificateStoreDeploymentDirectory= join-path $global:ESBRootFolder -childpath "CertificateStore\"
	New-Item $CertificateStoreDeploymentDirectory -ItemType Directory -Force | Out-Null
	$CertificateStorePackageSource=[String]::Format("{0}\CertificateStore\",$ESBDeploymentFolder)
	copy-item "$($CertificateStorePackageSource)*" -Destination $CertificateStoreDeploymentDirectory -Force -Recurse -ErrorAction Stop
	$CertificateFiles=Get-ChildItem $CertificateStoreDeploymentDirectory -Recurse -Force -File
	$CertificateNames=$MasterDeployXML.selectNodes("//Prerequisite/Certificate/file")
	
	foreach($CertificateFile in $CertificateFiles){
			if($CertificateNames.name -notcontains $CertificateFile.Name){
				Remove-Item $CertificateFile.FullName -Force -Recurse -ErrorAction Stop
		}
	}

	# DELETE EMPTY FOLDERS
	Get-ChildItem $CertificateStoreDeploymentDirectory -Recurse | Where-Object {$_.PSIsContainer} | Where-Object {$_.GetFiles().Count -eq 0} | Where-Object {$_.GetDirectories().Count -eq 0} | ForEach-Object { 
        write-host "Folder $($_.FullName) is empty and will be deleted.."
        remove-item $_.FullName
    }
}

foreach($DeploySequenceXML in $DeploySequencelist){
	$ConfigInstallDirectory=join-path $global:ESBRootFolder -ChildPath "Common\config\"
	New-Item $ConfigInstallDirectory -ItemType Directory -Force | out-null

	# GET APPLICATION DEPLOYMENT SEQUENCE XML AND lOAD XML SECTIONS
    if ($DeploySequenceXML.Attributes.Count -eq 0){
        $DeploySequenceXMLInnerText=$DeploySequenceXML
    }
    else{
        $DeploySequenceXMLInnerText=$DeploySequenceXML.InnerText
    }
	
	$DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
	$ApplicationDeploySequenceFile=[String]::Format("{0}\{1}",$XMLPackageRoot,$DeploySequenceXMLInnerText)	
	$DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
	$ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration	
	if($ApplicationConfiguration.ChildNodes){
	
	    # GET THE APPLICATION DEPLOYMENT FOLDER FOR NON BIZTALK APPLICATION
	    $ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $DeploySequenceName
	    $ApplicationPackageFolder=Join-Path $ESBDeploymentFolder -ChildPath $ApplicationShortName
			
			
		# GETTING CONFIG FILES 
        $RootXPath="//ConfigFiles"
	    $ConfigFiles=$ApplicationConfiguration.SelectNodes("$RootXPath/ConfigFile")
	    if($ConfigFiles.ChildNodes){
            Write-Host "`n --CONFIG DEPLOYMENT --"	
			$ConfigLogFile=[String]::Format("{0}\Logs\DeployConfig_Log.txt",$ESBDeploymentFolder)
			New-Item $ConfigLogFile -ItemType File -Force| Out-Null
			
            foreach($ConfigFile in $ConfigFiles){
                $ConfigFileName=$ConfigFile.GetElementsByTagName("FileName").innerText
                $configFileSourcePath=Get-ChildItem $ApplicationPackageFolder -Filter "*$($ConfigFileName)*" -Force -recurse
		        $ConfigDestination=$ConfigFile.GetElementsByTagName("Destination").innerText
                $ConfigJunctionSubdir=$ConfigFile.GetElementsByTagName("JunctionSubDirectory").innerText
                if($ConfigDestination -ieq "ConfigSubDir"){
			        Write-host "Deploying CONFIG : " $ConfigFileName
                    move-Item $configFileSourcePath.FullName -Destination $ConfigInstallDirectory -Force 
                }
                if($ConfigJunctionSubdir -ieq "Config"){
                    $JunctionDestination=join-path $ApplicationPackageFolder -ChildPath "config"
                    CreateFolderJunction -JunctionDestination $JunctionDestination -JunctionSource $ConfigInstallDirectory -LogPath $ConfigLogFile
            	}
				if($ConfigFileName -ieq "Mercator.Esb.Services.Mft.Service.exe.config"){
					$MftDeploymentManifestFile=Join-Path $ESBDeploymentFolder -ChildPath "XML\MftDeploymentManifest.xml"
					$MFTServiceConfigPath=Join-Path $ApplicationPackageFolder -childPath "Mercator.Esb.Services.Mft.Service.exe.config"
					$ReadMftConfig=[XML](GC $MFTServiceConfigPath -ErrorAction Stop)
					$MachineName=$([System.Net.Dns]::GetHostByName(($env:COMPUTERNAME)).HostName)
					Write-Host "SERVER:"$($MachineName.ToString().ToLower())
					$ReadMftDeploymentManifest=[XML](gc $MftDeploymentManifestFile -ErrorAction Stop)
					$FindReplaceInConfig=$ReadMftDeploymentManifest.SelectNodes("//DeploymentManifest/commonDeployment/findReplaceInConfigFile")

					# Find and replace host priority level in mft service config
					if(($MachineName -ilike "*mft*") -and ($FindReplaceInConfig)){
						$MftHostPriorityLevel=$($FindReplaceInConfig|?{$_.keyName -ieq "HostPriorityLevel"}).keyValue
						Write-Host "Updating host priority level.."
						$HostPriorityLevel=$ReadMftConfig.SelectSingleNode("//configuration/appSettings/add[@key='HostPriorityLevel']")
						$HostPriorityLevel.value=$MftHostPriorityLevel
						$ReadMftConfig.Save($MFTServiceConfigPath)
						Write-Host "Updated host priority level value in config:"$($HostPriorityLevel.value)
					}
					else{
						throw "Server is not of MFT type."
					}
				}
            }
        }
        else{
        	Write-Host "`n --CONFIG DEPLOYMENT already done--"	
	    }

		
		New-PSDrive -Name "K" -PSProvider "FileSystem" -Root "$ApplicationPackageFolder" 
		$GACLogFile=[String]::Format("{0}\Logs\Add_GAC_Log.txt",$ESBDeploymentFolder)
		if($ApplicationConfiguration.GacAssemblies.ChildNodes){
				$GACAssemblies=$ApplicationConfiguration.SelectNodes("//GacAssemblies/Assembly/AssemblyName")
		}
		if($ApplicationConfiguration.BizTalkApplications.BizTalkApplication.PipelineComponents.ChildNodes){
				$GACAssemblies +=$ApplicationConfiguration.SelectNodes("//PipelineComponents/PipelineComponent/PipelineComponentName")
		}
		if($GACAssemblies.childnodes){
			ForEach($AssemblyName in $($GACAssemblies.innerText)){
				$AssemblyPath=gci "K:\" -recurse -Filter "*.dll"| ?{$_.Name -ieq $AssemblyName}
				ForEach($file in $($AssemblyPath.FullName)){
					$file
					$GACLogFile
					Add-GAC  -AssemblyPath $file | Add-Content -Path $GACLogFile -Force
				}
			}
		}
		Remove-PSDrive -Name "K" -ErrorAction SilentlyContinue | Out-Null
		# INSTALL MFT SERVICE
		$NTServices=$ApplicationConfiguration.SelectNodes("//NTServices")
	    if($NTServices.childnodes){
			$ServiceDeploymentFolder=GetApplicationDeploymentFolder -ApplicationName $DeploySequenceName
			$ApplicationType="BizTalkServiceEsb"
			$WindowsServiceInstallationLogFile=[String]::Format("{0}\Logs\MFTServiceInstallation_Log.txt",$ESBDeploymentFolder)
            Write-Host "`n -- START SERVICES --"	
            foreach($Service in $($NTServices.NTService)){
                $ServiceName=$Service.GetElementsByTagName("NTServiceName").innerText
                $ServcieDisplayName=$Service.GetElementsByTagName("NTServiceDisplayName").innerText
	            $ServiceExeName=$Service.GetElementsByTagName("NTServiceAssemblyName").innerText
	            $Serviceuser=$Service.GetElementsByTagName("NTServiceUserName").innerText
	            $ServicePassword=$Service.GetElementsByTagName("NTServiceUserPassword").innerText
				$InstallWithInstallUtil=$Service.NTServiceName.InstallWithInstallUtil
				$Service.NTServiceName.InstallWithInstallUtil
				Write-Host "Deployment folder name:" $ServiceDeploymentFolder
				
				if($InstallWithInstallUtil -ieq "True"){
				    Re-InstallWindowsService -ServiceName $ServiceName -ServiceDisplayName $ServcieDisplayName  -deploymentFolderName $ServiceDeploymentFolder -ServiceExeName $ServiceExeName -username $Serviceuser -password $ServicePassword -ApplicationType $ApplicationType -StartUpType "Automatic" -InstallWithInstallUtil $true | Add-Content $WindowsServiceInstallationLogFile -Force
				}
			    else{
	            # INSTALLING & STARTING WINDOWS SERVICE
		        	Write-Host "Installing: " $ServiceName
			        Re-InstallWindowsService -ServiceName $ServiceName -ServiceDisplayName $ServcieDisplayName  -deploymentFolderName $ServiceDeploymentFolder -ServiceExeName $ServiceExeName -username $Serviceuser -password $ServicePassword -ApplicationType $ApplicationType -StartUpType "Automatic" | Add-Content $WindowsServiceInstallationLogFile -Force
	        	}
			}
			if($Environment -ine "PCORP"){
				Start-WindowsService -serviceName $serviceName
			}
		}
	}

}