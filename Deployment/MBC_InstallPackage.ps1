Param
(
	[ValidateSet("Mercator.Legacy.Back","Mercator.Legacy.Data","Mercator.Legacy.Eai","Mercator.Legacy.Front")] 
        [String] $PackageType,
	[ValidateSet("ClassicFront","ClassicBack")]
        [String] $ServerType,
	[String]$Environment,
    [String]$BuildVersion
)
Clear-host

if (!$ServerType){
    $ServerType="ClassicBack"
    $Environment="DCORPBIS"
    $PackageType="Mercator.Legacy.Back"
    $BuildVersion="31.0.20191127.184531"
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
    "ClassicFront" {
        $CommonConfigFolder=Join-Path $global:FrontLegacyRoot -ChildPath "Common" | Join-Path -ChildPath "Config"
    }
    "ClassicBack" {
        $CommonConfigFolder=Join-Path $global:BackofficeRoot -ChildPath "Common" | Join-Path -ChildPath "Config"
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
        $DeploymentRoot=Join-Path $global:LocalMBCWorkFolder -ChildPath $BuildVersion
    }
    "Mercator.Legacy.Eai" {
        $DeploymentRoot=$global:BackofficeEaiRoot
        $JunctionExeFolder=$GacUtilExeFolder=Join-Path $global:BackofficeEaiRoot -ChildPath "InstallationUtilities" | Join-Path -ChildPath "Executables"
        $installutillExePath=Join-Path $global:BackofficeEaiRoot -ChildPath "InstallationUtilities" | Join-Path -ChildPath "Executables" | Join-Path -ChildPath "InstallUtil.exe"
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

$Rootlogfolder=[String]::Format("{0}\Logs\Install_{1}",$DeploymentRoot,(Get-Date -Format yyyyMMdd-hhmmss))
$DeployStatusFile=Join-Path $DeploymentRoot -ChildPath "DeployStatus.xml"

if (Test-Path $DeployStatusFile){
	Write-Host "DeployStatus.xml found."
}
else{
    CreateDeployStatusXML $DeploymentRoot
}
$DeployStatusXML=[xml](get-content filesystem::$DeployStatusFile -Force )

#Copy the Package on the server
if ($DeployStatusXML.DeployStatus.DeployPackage.status -ne "Succeeded"){
    Write-Host "Copying zip : " $PackageZip
    $WorkingFolder=Join-Path $DeploymentRoot -ChildPath ($PackageType + ".Work")
    New-Item $WorkingFolder -ItemType Directory  -Force| Out-Null
    #copy zip to working folder
    Copy-Item $PackageZip -destination $WorkingFolder -Force -Recurse
    $localZip=[String]::Format("$WorkingFolder\{0}.zip", $PackageType)
    #unzip to working folder
    Unzip -zipfile $localZip -outpath (Join-Path $WorkingFolder -ChildPath "unzip")

    #copy all folders from unzip folder to deployment root
    #first delete existing folders in deployment root
    $exCeptionFolders=@("Deployment","Eai","InstallationUtilities","InstallUtilities","Management")
    Get-ChildItem (Join-Path $WorkingFolder -ChildPath "unzip") | Where-Object {$_.PSIsContainer } | ForEach-Object {
        $currentFolder=$_
        if ($exCeptionFolders -inotcontains $currentFolder.Name){
            if (Test-Path -Path (Join-Path $DeploymentRoot -ChildPath $currentFolder.Name)){
                Remove-Item (Join-Path $DeploymentRoot -ChildPath $currentFolder.Name) -Force -Recurse
            }
        }

        Copy-Item $_.FullName -Destination (Join-Path $DeploymentRoot -ChildPath $_.Name) -Force -Recurse
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
    $paramxmlfilepath=Join-Path $DeploymentRoot -ChildPath "xml\Environments.xml"
	#Changing environemnt to PROD for config issue on 18/10/20202 R33 PCORP
	$ConfigProdEnvironment=$Environment
	if($Environment -ieq "PCORP"){
		$ConfigProdEnvironment="PROD"
	}
    ConfigDeployer -ParameteXMLFile $paramxmlfilepath -Environment $ConfigProdEnvironment -DeploymentFolder $DeploymentRoot 
    #add succeeded to DeployStatusXML
    AddElementWithAttributeToXml -XmlPath $DeployStatusFile -ParentElement "DeployStatus" -NewElementName "DeployConfig" -NewAttribute "status" -NewAttributeValue "Succeeded"
}
else{
    Write-Host "Configuration was already deployed."
}

# Reading the Master Deploy Sequence
$DeploymentxmlDirectory=join-path $DeploymentRoot -ChildPath "XML"

# Check attribute type of files and remove all ReadOnly attributes of Deploy sequence XMLs
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
    exit
}

$DeploySequencelist=$MasterDeployXML.'Master.DeploySequence'.'DeployPackages.DeploySequence'.DeployPackage 

# Prerequisites setup
$PrerequisitesDeployStatus=$MasterDeployXML.'Master.DeploySequence'.Prerequisites.status
if ([string]::IsNullOrEmpty($PrerequisitesDeployStatus) -or ($PrerequisitesDeployStatus -ne "Deployed")){
    AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/Prerequisites" -NewAttribute "status" -NewAttributeValue "Deploying"

    $PreRequisiteName=$MasterDeployXML.'Master.DeploySequence'.Prerequisites.Prerequisite

    # System Variable
    $SystemVariables=$PreRequisiteName.SystemVariables.SystemVariable
    if ($SystemVariables){
        Write-Host "`n -- Adding Environment Variables --"
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
    }

    #registry
    $registryNode=$PreRequisiteName.SelectSingleNode("//Prerequisite[@name='RegistryEntry']")
    if ($registryNode){
        Write-Host "`n -- Adding Registry Entries --"
        ForEach($node in $registryNode.add){
            #New-Item $node.KeyPath -Force | New-ItemProperty -Name $node.KeyName -Value $node.Keyvalue -Force | Out-Null
            ReSet-RegistryValue -registryKey $node.KeyPath -RegistryName $node.KeyName -Registryvalue $node.Keyvalue
        }
    }
	
    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/Prerequisites" -Attribute "status" -NewAttributeValue "Deployed"
}
elseif ($PrerequisitesDeployStatus -eq "Deployed"){
    Write-Host "Prerequisites deployment already done."
}

foreach($DeploySequenceXML in $DeploySequencelist){
    #clear All Variables for each application
	$DeploySequenceName=""
	$GACAssemblies=$NTServices=$ConfigFiles=$ConsoleApplications=$null

	#Get Application Deployment Sequence XML and load XML sections
    $DeploySequenceXMLInnerText=$DeploySequenceXML.name
    $currentServerType=$DeploySequenceXML.serverType
	$DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
	$ApplicationDeploySequenceFile=[String]::Format("{0}\XML\{1}",$DeploymentRoot,$DeploySequenceXMLInnerText)	
	$DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
	$ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
    $AfterDeploymentActions=$DeploySequenceReader.'Package.DeploySequence'.AfterDeploymentActions
    $SystemConfiguration=$DeploySequenceReader.'Package.DeploySequence'.SystemConfiguration
	
    $masterXPpath=[string]::Format("//DeployPackage[@name='{0}']",$DeploySequenceXMLInnerText)
    $DeployPackageNode=$MasterDeployXML.SelectSingleNode($masterXPpath)
    $CurrenApplicationDeployStatus=$DeployPackageNode.status
    if ([string]::IsNullOrEmpty($CurrenApplicationDeployStatus) -or ($CurrenApplicationDeployStatus -ne "Deployed")){
        AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -NewAttribute "status" -NewAttributeValue "Deploying"
		Write-Host "===================================$($DeploySequenceName) Installation========================================================="	
		
	    #getting the Biztalk Application Info
	    if($ApplicationConfiguration.ChildNodes){
			
		    #Preparing the Appliction log Folder	
		    $Installlogfolder=Join-Path $Rootlogfolder -ChildPath $DeploySequenceName
		    New-Item $Installlogfolder -ItemType Directory -Force | Out-Null
			
		    #getting Config Files 
            $RootXPath="//ConfigFiles"
		    $ConfigFiles=$ApplicationConfiguration.SelectNodes("$RootXPath/ConfigFile")
		    if($ConfigFiles.ChildNodes){
                #get Deploying flag
                $CurrenDeployStatus=$ApplicationConfiguration.SelectSingleNode("$RootXPath/DeployStatus").status
                if ([string]::IsNullOrEmpty($CurrenDeployStatus) -or ($CurrenDeployStatus -ne "Deployed")){
                    #set Deploying flag
                    AddElementDeploymentStarted -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
                    $ConfigLogFile=[String]::Format("{0}\DeployConfig_Log.txt",$Installlogfolder)
	                Write-Host "`n --CONFIG DEPLOYMENT --"	
	                foreach($ConfigFile in $ConfigFiles){
	                    $ConfigFileName=$ConfigFile.name
	                    $ConfigJunctionSubdir=$ConfigFile.JunctionSubDirectory
                        $ConfigDestination=$ConfigFile.Destination -ireplace "%serverType%", $currentServerType
                        $configRootFolder=join-path $DeploymentRoot -ChildPath $ConfigDestination
                        $configFullName=Join-Path $configRootFolder -ChildPath $ConfigFileName

	                    if($ConfigJunctionSubdir -ieq "Config"){
	                        $JunctionDestination= Join-Path $configRootFolder -ChildPath "config"
	                        CreateFolderJunction -JunctionDestination $JunctionDestination -JunctionSource $CommonConfigFolder -LogPath $ConfigLogFile -InstallUtilitiesPath $JunctionExeFolder
	                    }

                        $InjectValuesFromRegistry=$ConfigFile.InjectValuesFromRegistry
                        if ($InjectValuesFromRegistry){
                            $InjectValuesFromRegistry.add | ForEach-Object{
                                $configKey=$_.configKey                            
                                $newConfigValue=Get-RegistryValue -registryKey $_.registryKey -RegistryName $_.registryName
                                SetValueInConfig -XmlPath $configFullName -Key $configKey -NewValue $newConfigValue
                            }
                        }

                        $renameAfterDeployment=$ConfigFile.RenameAfterDeployment
                        if ($renameAfterDeployment){
                            rename-item -Path $configFullName -NewName $renameAfterDeployment
                        }
                            
                    }
                    #set Deployed flag
                    SetElementDeploymentSucceeded -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
                }
                else{
                    Write-Host "`n --CONFIG DEPLOYMENT already done--"	
		        }
	        }
			
		    $DeploymentFiles=$ApplicationConfiguration.SelectNodes("//DeploymentFiles/Folders/Folder[@destinationType='Remote']")
		    if($DeploymentFiles.childnodes){
	            Write-Host "`n --Deploy Remote Folders--"	
	            foreach($Folder in $DeploymentFiles){
				    $sourceSubpath=$($Folder.tfsPath).Replace("/","`\")
				    $sourceFolder=[string]::Format("{0}\Remote\{1}\",$ApplicationPackageFolder, $sourceSubpath)
				    $Destination=$Folder.GetElementsByTagName("Destination").innerText
				    Copy-Item "$($sourceFolder)*" -Destination $Destination -Force -Recurse 
				}
			}
			
		    $DeploymentFiles=$ApplicationConfiguration.SelectNodes("//DeploymentFiles/Folders/Folder[@destinationType='AppShare']")
		    if($DeploymentFiles.childnodes){
	            Write-Host "`n --Deploy AppShare Folders--"	
	            foreach($Folder in $DeploymentFiles){
				    $sourceFolder=Join-Path $DeploymentRoot -ChildPath $folder.Destination
				    $Destination=Join-Path $global:AppShareRoot -ChildPath $Environment | Join-Path -ChildPath $folder.Destination
				    Copy-Item "$($sourceFolder)\*" -Destination $Destination -Force -Recurse 
				}
			}
			
			#load all GAC assemblies
			$GacAssembliesPresent=$false
		    if($ApplicationConfiguration.GacAssemblies.ChildNodes){
                $_GacFolder=$ApplicationConfiguration.GacAssemblies.gacFolder -ireplace "%serverType%", $currentServerType
                $GacFolder=Join-Path $DeploymentRoot -ChildPath $_GacFolder
				$GACAssemblies=$ApplicationConfiguration.SelectNodes("//GacAssemblies/Assembly")
				$CurrenGacDeployStatus=$ApplicationConfiguration.SelectSingleNode("//GacAssemblies/DeployStatus").status		    
				#get Deploying flag
				if ([string]::IsNullOrEmpty($CurrenGacDeployStatus) -or ($CurrenGacDeployStatus -ne "Deployed") ){
					#set Deploying flag					
                    AddElementDeploymentStarted -XmlPath $ApplicationDeploySequenceFile -ParentElement "//GacAssemblies" 					

					$GACLogFile=[String]::Format("{0}\AddGAC_Log.txt",$Installlogfolder)	
					Write-Host "--- *** ADD GAC *** ---"
					ForEach($AssemblyName in $GACAssemblies){
						$AssemblyPath=gci $GacFolder -recurse -Filter "*.dll"| ?{$_.Name -ieq $AssemblyName.name}
						ForEach($file in $($AssemblyPath.FullName)){
							Add-GAC  -AssemblyPath $file  -GacUtilPath $GacUtilExeFolder | Add-Content -Path $GACLogFile -Force
						}
					}
                    #set Deployed flag
					SetElementDeploymentSucceeded -XmlPath $ApplicationDeploySequenceFile -ParentElement "//GacAssemblies" 					
				}
				else{
					Write-Host "`n --GAC DEPLOYMENT already done--"	
				}
		    }
			
            #installing COM+
            $RootXPath="//ComPlusComponents/ComPlusComponent"
	   	    $ComPlusComponents=$ApplicationConfiguration.ComPlusComponents.ComPlusComponent
		    if($ComPlusComponents.ChildNodes){
                
                foreach($ComPlusComponent in $ComPlusComponents){
                
                    #get Deploying flag
                    $CurrenDeployStatus=$ApplicationConfiguration.SelectSingleNode("$RootXPath/DeployStatus").ComPlusStatus
                    if ([string]::IsNullOrEmpty($CurrenDeployStatus) -or ($CurrenDeployStatus -ne "Deployed")){
                        #set Deploying flag
                        AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath -NewAttribute "ComPlusStatus" -NewAttributeValue "Deploying"

                        $AssemblyPath=Get-ChildItem $DeploymentRoot  -recurse| ?{!($_.PSISContainer) -and ($_.Name -ieq $ComPlusComponent.AssemblyName)}
                        #we don't expect more then 1 assembly, but if it's more, pick the first
                        if ($AssemblyPath.count -gt 1){
                            $AssemblyPath=$AssemblyPath[0]
                        }
						if ($ComPlusComponent.ApplicationRootDirectory){
                            $applicationRootSubDir=$ComPlusComponent.ApplicationRootDirectory  -ireplace "%serverType%", $currentServerType
                            $applicationRootDir=join-path $DeploymentRoot -ChildPath $applicationRootSubDir
                        }
                        else{
                            $applicationRootDir=$null
                        }
						
                        Create-ComPlus -assemblyName $AssemblyPath.FullName -targetApplication $ComPlusComponent.ComPlusName -identity $ComPlusComponent.ComPlusIdentity -pswd $ComPlusComponent.ComPlusPassword -runForever $ComPlusComponent.ComPlusRunForEver -reCreate $true -RegSvcsVersion $ComPlusComponent.RegSvcsVersion -applicationRootDirectory $applicationRootDir
                                              
                        $ComPlusComponent.Components.ChildNodes | ForEach-Object{
                            if ($_.MaximumPoolSize){
                                $ComponentName=$_.name
                                $regKey=$_.MaximumPoolSize.registryKey
                                $regName=$_.MaximumPoolSize.registryName
                                if ($_.MaximumPoolSize.getValueFromRegistry -ieq "true"){
                                    $propValue=Get-RegistryValue -registryKey $regKey -RegistryName $regName
                                }
                                else{
                                    $propValue=$_.MaximumPoolSize.value
                                }
                                Set-ComPlusConstructorString -targetApplication $ComPlusComponent.ComPlusName -targetComponent $ComponentName -propertyName "MaxPoolSize" -propertyValue $propValue
                            }
                            if ($_.SetConstructorString){
                                $ComponentName=$_.name
                                $propValue=$_.SetConstructorString.constructorString
                                Set-ComPlusConstructorString -targetApplication $ComPlusComponent.ComPlusName -targetComponent $ComponentName -constructorString $propValue
                            }
                        }

                        #set Deployed flag
                        SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath -Attribute "ComPlusStatus" -NewAttributeValue "Deployed"


                    }
                    else{
                        Write-Host "`n --COM+ already deployed--"	
		            }
                }
	        }

            #register assemblies
		    $RegisterAssemblies=$ApplicationConfiguration.SelectNodes("//RegisterAssemblies/Assembly")
		    if($RegisterAssemblies){
	            Write-Host "`n --register assemblies--"	
	            foreach($Assembly in $RegisterAssemblies){
				    $assemblyName=$Assembly.name
                    $RegisterTool=$Assembly.registerTool

                    $AssemblyPath=Get-ChildItem $DeploymentRoot  -recurse| ?{!($_.PSISContainer) -and ($_.Name -ieq $assemblyName)}
                    #we don't expect more then 1 assembly, but if it's more, pick the first
                    if ($AssemblyPath.count -gt 1){
                        $AssemblyPath=$AssemblyPath[0]
                    }

                    Register-Assembly -assemblyPath $AssemblyPath.FullName -Registertool $RegisterTool
				}
			}

		    $NTServices=$ApplicationConfiguration.SelectNodes("//NTServices")
		    if($NTServices.childnodes){
			    $ServiceLogFile=[String]::Format("{0}\InstallService_Log.txt",$Installlogfolder)
			    New-Item $ServiceLogFile -ItemType File -Force | Out-Null
	            Write-Host "`n -- START SERVICES --"	
	            foreach($Service in $($NTServices.NTService)){
	                
	                $ServiceName=$Service.GetElementsByTagName("NTServiceName").innerText
	                $ServcieDisplayName=$Service.GetElementsByTagName("NTServiceDisplayName").innerText
		            $ServiceExeName=$Service.GetElementsByTagName("NTServiceAssemblyName").innerText
		            $Serviceuser=$Service.GetElementsByTagName("NTServiceUserName").innerText
		            $ServicePassword=$Service.GetElementsByTagName("NTServiceUserPassword").innerText
					$InstallWithInstallUtil=$Service.NTServiceName.InstallWithInstallUtil
                    $NtExePath=Get-ChildItem $DeploymentRoot -Filter $ServiceExeName -Recurse
					Write-Host "Deployment folder name:" $NtExePath.FullName

                    #on the backoffice webfarm, a service can be active on node1 or node 2, or both. This is indicated with attribute "activeOnBackOfficeNode"
		            #when "activeOnBackOfficeNode" is set, the registry on the local machine will be read to determine on which node the current deployment pipeline is running
		            #the path in the registry is set in the attributes "registryKey" and "registryName".

                    if ($DeploySequenceXML.activeOnBackOfficeNode){
                        $currentBackOfficeNode=Get-RegistryValue -registryKey $DeploySequenceXML.registryKey -RegistryName $DeploySequenceXML.registryName
                        #break script is registry is not set
                        if (!$currentBackOfficeNode){
                            Write-Error "registry key ""BackOfficeNode"" not set on server $($env:COMPUTERNAME)"
                            exit 1
                        }
                        $arrActiveOnBackOffice=$DeploySequenceXML.activeOnBackOfficeNode.split(",")
                        $startupType="Disabled"
                        $currentBackOfficeNode.Split(",") | ForEach-Object {
                            if($arrActiveOnBackOffice -Contains $_ ){
                                $startupType="Automatic"
                            }
                        }
                    }
					else{
						$startupType="Automatic"
					}
					
					if($InstallWithInstallUtil -ieq "True"){
                        #issue: InstallUtil does not work with startuptype "Automatic". the correct = "Auto"
                        if ($startupType -ieq "Automatic"){
                            $startupType="Auto"
                        }
					    Re-InstallWindowsService -ServiceName $ServiceName -ServiceDisplayName $ServcieDisplayName  -deploymentFolderName $NtExePath.DirectoryName -InstallUtilExePath $installutillExePath -ServiceExeName $ServiceExeName -username $Serviceuser -password $ServicePassword -ApplicationType $PackageType -StartUpType $startupType -InstallWithInstallUtil $true  | Add-Content $ServiceLogFile -Force
					}
				    else{
		                # Installing and starting Windows Service
			            Write-Host "Installing: " $ServiceName
				        Re-InstallWindowsService -ServiceName $ServiceName -ServiceDisplayName $ServcieDisplayName  -deploymentFolderName $NtExePath.DirectoryName -ServiceExeName $ServiceExeName -username $Serviceuser -password $ServicePassword -ApplicationType $PackageType -StartUpType $startupType | Add-Content $ServiceLogFile -Force
		        	}
				}
			
	        }
			
		}
	    else{
		    Write-host "No application components found : " $DeploySequenceName
	    }

        if($AfterDeploymentActions.ChildNodes){

            $RootXPath="//RunPrograms/Program"
	   	    $RunPrograms=$AfterDeploymentActions.RunPrograms.Program
		    if($RunPrograms.ChildNodes){
                
                foreach($Program in $RunPrograms){
                
                    #get Deploying flag
                    $CurrenDeployStatus=$AfterDeploymentActions.SelectSingleNode("$RootXPath").RunStatus
                    if ([string]::IsNullOrEmpty($CurrenDeployStatus) -or ($CurrenDeployStatus -ne "RunFinished")){
                        #set Deploying flag
                        AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath -NewAttribute "RunStatus" -NewAttributeValue "RunStarted"
                        $ProgramFullPath=Join-Path $DeploymentRoot -ChildPath $Program.programFilePath 

	                    $out=Invoke-Expression "& `"$ProgramFullPath`""  
	                    if($LastExitCode -eq '0')	    {
	                        Write-Host "program has run without error: " $(Split-Path $ProgramFullPath -leaf) |Out-Host
	                    }
                        else{
                            throw "Error running $(Split-Path $ProgramFullPath -leaf). `n LastExitCode: $LastExitCode.  `n ErrorMessage: $out."
                        }

                        #set RunFinished flag
                        SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath -Attribute "RunStatus" -NewAttributeValue "RunFinished"

                    }
                }
            }
        }
        else{
		    Write-host "No AfterDeploymentActions found : " $DeploySequenceName
	    }
		
        if($SystemConfiguration.ChildNodes){

	   	    $LocalFolders=$SystemConfiguration.Folders.LocalFolders.Folder
                
            foreach($Folder in $LocalFolders){
                $Subfolder=$Folder.name -ireplace "%serverType%", $currentServerType
                $FullFolder=Join-Path $DeploymentRoot -ChildPath $Subfolder 
                if (! (Test-Path $FullFolder)){                        
                    New-Item -Path $FullFolder -ItemType Directory -Force 
                }
            }

        }
        else{
		    Write-host "No SystemConfiguration found : " $DeploySequenceName
	    }

        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "Deployed"
		Write-Host "===================================$($DeploySequenceName) End Installation========================================================="
    }
    elseif ($CurrenApplicationDeployStatus -eq "Deployed"){
        Write-Host "$DeploySequenceName deployment already done."
    }
}

#deployment ok, update 
SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "Deployed"
Write-Host "LastExitCode: $($LastExitCode)"
Write-Host "===================================  $([io.path]::GetFileNameWithoutExtension($MasterDeploySequencePath))  -  End Installation  ========================================================="
