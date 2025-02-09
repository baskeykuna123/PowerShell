Param
(
[String]$ServerType,
[String]$Environment,
[String]$Platform,
[String]$BuildVersion,
[String]$ApplicationServerType
)
Clear-host

if (!$ServerType){
    $ServerType="Admin"
    $Environment="dcorp"
    $Platform="Esb"
    $BuildVersion="36.24.20210701.150056"
	$ApplicationServerType='MFT'
}

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
$PackageFolder= [String]::Format("$global:NewPackageRoot\{0}\{1}",$Platform,$BuildVersion)

if(-not (Test-Path $PackageFolder)){
	Write-Host "Package Not found : " $PackageFolder
	Exit 1
}

$ESBDeploymentFolder=Join-Path $global:ESBRootFolder -ChildPath $Platform
$Rootlogfolder=[String]::Format("{0}\Logs\Install_{1}",$ESBDeploymentFolder,(Get-Date -Format yyyyMMdd-hhmmss))
$DeployStatusFile=Join-Path $ESBDeploymentFolder -ChildPath "DeployStatus.xml"


if (Test-Path $DeployStatusFile){
	Write-Host "DeployStatus.xml found."
}
else{
    CreateDeployStatusXML $ESBDeploymentFolder
}
$DeployStatusXML=[xml](get-content filesystem::$DeployStatusFile -Force )

#Copy the Package on the server

if ($DeployStatusXML.DeployStatus.DeployPackage.status -ne "Succeeded"){
Write-Host "Copying Package : " $BuildVersion
    New-Item $ESBDeploymentFolder -ItemType Directory  -Force| Out-Null
    cmd /c "net use K: $PackageFolder"
	sleep -Seconds 60
    Copy-Item "K:\*" -destination $ESBDeploymentFolder -Force -Recurse
    cmd /c "net use K: /d /y"
    #add succeeded to DeployStatusXML
    AddElementWithAttributeToXml -XmlPath $DeployStatusFile -ParentElement "DeployStatus" -NewElementName "DeployPackage" -NewAttribute "status" -NewAttributeValue "Succeeded"
}
else{
    Write-Host "Package : " $BuildVersion " was already copied."
}

$paramxmlfilepath=Join-Path $global:ESBRootFolder -ChildPath "$Platform\ESBDeploymentParameters_Resolved.xml"

#Setting the Configuration based on the environment
Write-Host "Environment:"$Environment
if ($DeployStatusXML.DeployStatus.DeployConfig.status -ne "Succeeded"){
    ConfigDeployer -ParameteXMLFile $paramxmlfilepath -Environment $Environment -DeploymentFolder $ESBDeploymentFolder
    #add succeeded to DeployStatusXML
    AddElementWithAttributeToXml -XmlPath $DeployStatusFile -ParentElement "DeployStatus" -NewElementName "DeployConfig" -NewAttribute "status" -NewAttributeValue "Succeeded"
}
else{
    Write-Host "Configuration was already deployed."
}

# Reading the Master Deploy Sequence
$DeploymentxmlDirectory=join-path $ESBDeploymentFolder -ChildPath "XML"

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

if($Platform -ieq "Esb"){
	$BuildOutputPath="\\svw-be-bldp001\E$\P.ESB"
	$MasterDeploySequencePath=join-path $DeploymentxmlDirectory  "Mercator.Esb.Master.DeploySequence.xml"
	#$MasterDeploySequencePath="C:\Users\CH36107\Desktop\Mercator.Esb.Master_Kurt.DeploySequence.xml"  ##  => To delete
	$MasterDeployXML=[xml](get-content filesystem::$MasterDeploySequencePath -Force )
}
if($Platform -ieq "Eai"){
	$BuildOutputPath="\\svw-be-bldp001\E$\P.EAI"
	$MasterDeploySequencePath=Join-Path $DeploymentxmlDirectory "Mercator.Esb.Eai.Master.DeploySequence.xml"
	$MasterDeployXML=[xml](get-content filesystem::$MasterDeploySequencePath -Force )
}

Write-Host "=============================================================================="
Write-Host "Build Version              :"$BuildVersion
Write-Host "Package Folder             :"$PackageFolder
Write-Host "Master Deploy Sequence Path:"$MasterDeploySequencePath
Write-Host "Deployment XML directory   :"$DeploymentxmlDirectory
Write-Host "Esb Deployment Folder      :"$ESBDeploymentFolder
Write-Host "=============================================================================="

$overallDeployStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.status
if ([string]::IsNullOrEmpty($overallDeployStatus)){
    AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -NewAttribute "status" -NewAttributeValue "Deploying"
}
elseif ($overallDeployStatus -eq "Deployed"){
    Write-Host "Deployment already done."
}

#$DeploySequencelist=$MasterDeployXML.'Master.DeploySequence'.'DeployPackages.DeploySequence'.DeployPackage 
$DeploySequencelist=$MasterDeployXML.'Master.DeploySequence'.SelectSingleNode("//DeployPackages.DeploySequence")
$DeploySequencelist=$DeploySequencelist.DeployPackage
$ReadResolvedDeploymentParametersXMLFile =[XML](Gc $paramxmlfilepath)

# Read attribute for ApplicationToExclude
$ExcludedAplicationList=$ReadResolvedDeploymentParametersXMLFile.SelectNodes("//Parameters/EnvironmentParameters/Environment[@name='$Environment']/add[@key='ApplicationToExclude']").value
Write-Host "Application to be excluded:" $ExcludedAplicationList
Write-Host `n
$ListofDeploySequences=@()

if($ApplicationServerType -ieq "Mft"){
	ForEach($deploysequencename in $DeploySequencelist){
		if($($deploysequencename.installOnServerType) -ilike "*Mft*"){
        $ApplicationName=$($deploysequencename.'#text') -ireplace ".DeploySequence.xml",""
			if($ExcludedAplicationList -inotlike "*$ApplicationName*"){
				$ListofDeploySequences+=$($deploysequencename.'#text')
			}
		}
	}
}
else{
	Foreach($deploysequencename in $DeploySequencelist){
	    $ApplicationName=$deploysequencename -ireplace ".DeploySequence.xml",""
	    if($ExcludedAplicationList -inotlike "*$ApplicationName*"){
	        $ListofDeploySequences+=$deploysequencename
	    }
	}
}

$DeploySequencelist=$ListofDeploySequences

# Prerequisites setup
$PrerequisitesDeployStatus=$MasterDeployXML.'Master.DeploySequence'.Prerequisites.status
if ([string]::IsNullOrEmpty($PrerequisitesDeployStatus) -or ($PrerequisitesDeployStatus -ne "Deployed")){
    AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/Prerequisites" -NewAttribute "status" -NewAttributeValue "Deploying"

    #$PreRequisiteName=$MasterDeployXML.'Master.DeploySequence'.Prerequisites.Prerequisite
	
	$Prerequisites=$MasterDeployXML.'Master.DeploySequence'.SelectSingleNode("//Prerequisites")
	$PreRequisiteName=$Prerequisites.Prerequisite
	ForEach($Prerequisite in $PreRequisiteName){
		Write-Host "Prerequisite :"$($Prerequisite.name)
		
	    #  BizTalk Application
	    $BizTalkApp=$Prerequisite.BiztalkApplication.Name
		
		# System Variable
	    $SystemVariables=$Prerequisite.SystemVariables.SystemVariable
		
		# Security collections
    	$securityCollections=$MasterDeployXML.selectNodes("//Prerequisite[@name='Security']/Collection")
		
		# Expressions to be executed for Pre-requistes
		Switch($($Prerequisite.name)){
			"EnvironmentVariables" {
                    Function ExecutePreRequisiteFunction(){
                        $functn=${function:AddEnvVariable}
                        & $functn $SystemVariables
                    }
                }

			"BizTalkApplication" {
                    Function ExecutePreRequisiteFunction(){
                        $functn=${function:CheckBiztalkApp}
                        & $functn $BizTalkApp
                     }   
                }
			"Security" {
                    Function ExecutePreRequisiteFunction(){
                        $functn=${function:DeploySecurity}
                        & $functn $MasterDeploySequencePath         
                    }
                }
		}
		
		# Pre-requisite functions to be executed as per application server type
		Switch($ApplicationServertype){
			"MFT"	{
				If($($Prerequisite.installOnServerType) -ilike "*Mft*"){
					ExecutePreRequisiteFunction
				}
			}
			Default	{
				ExecutePreRequisiteFunction
			}
		}
	}

	# Copy Remote Folders from package to the DfsFileAppshare and EsbFileCluster shared location
	if(($ServerType -ieq "Admin") -and ($platform -ieq "esb") -and ($ApplicationServerType -ine "MFT")){							
		$ESBparameterXML=join-path $ESBDeploymentFolder -childpath "ESBDeploymentParameters_Resolved.xml"
	    #using Framework application Seuence to read all System Configuration
		$FrameworkDeploySequenceFile=[String]::Format("{0}\XML\Mercator.Esb.Framework.DeploySequence.xml",$ESBDeploymentFolder)	
	    $DeploySequenceReader=[XML](gc $FrameworkDeploySequenceFile)
		$systemConfiguration=$DeploySequenceReader.'Package.DeploySequence'.SystemConfiguration		
		$DFSAppFileShareFolder=$($systemConfiguration.Folders.RemoteFolders.DfsAppFileShare).Name		
		$ESBFileClusterFolder=$($systemConfiguration.Folders.RemoteFolders.EsbFileCluster).Name	
		$DFSUserFileShareFolder=$($systemConfiguration.Folders.RemoteFolders.DfsUserFileShare).Name
		$xml=[xml](gc $ESBparameterXML)
		$GlobalParameters=$xml.SelectNodes("//Parameters/GlobalParameters/add")
		$EnvironmentParameters=$xml.SelectNodes("//Parameters/EnvironmentParameters/Environment[@name='$Environment']/add")
		
		# Copy folders to DfsFileAppShare shared location from package source
		$DFSappShare=$($GlobalParameters |?{$_.key -ieq $DFSAppFileShareFolder}).Value
		$DFSappShare=Join-Path $DFSappShare -ChildPath $Environment
		$DFSappShare=$DFSappShare+"\"
		$DFSPackageSource=[String]::Format("{0}\SharedFolders\{1}\",$ESBDeploymentFolder,$DFSAppFileShareFolder)
		Copy-Item -path "$($DFSPackageSource)\*" -Destination "$DFSappShare"  -Force -Recurse -ErrorAction Stop 
		
		# Copy folders to EsbFileCluster shared location  from package source
		$EsbClusterShare=$($EnvironmentParameters | ?{$_.Key -ieq $ESBFileClusterFolder}).Value
		$EsbClusterShare="\\"+$EsbClusterShare+"\"
		$EsbFileClusterPackageSource=[String]::Format("{0}\SharedFolders\{1}\",$ESBDeploymentFolder,$ESBFileClusterFolder)
		Copy-Item -path "$($EsbFileClusterPackageSource)\*" -Destination "$EsbClusterShare"  -Force -Recurse -ErrorAction Stop 

		# Copy folders to DfsUserFileShare shared location from package source
		$DFSUserShare=$($GlobalParameters |?{$_.key -ieq $DFSUserFileShareFolder}).Value
		$DFSUserShare=Join-Path $DFSUserShare -ChildPath $Environment
		$DFSUserShare=$DFSUserShare+"\"
		$DFSUserPackageSource=[String]::Format("{0}\SharedFolders\{1}\",$ESBDeploymentFolder,$DFSUserFileShareFolder)
		Copy-Item -path "$($DFSUserPackageSource)\*" -Destination "$DFSUserShare"  -Force -Verbose -Recurse -ErrorAction Stop
	}
	
    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/Prerequisites" -Attribute "status" -NewAttributeValue "Deployed"
}
elseif ($PrerequisitesDeployStatus -eq "Deployed"){
    Write-Host "Prerequisites deployment already done."
}

#$DeploySequencelist="Mercator.Esb.Framework.DeploySequence.xml"
#$DeploySequencelist="Mercator.Esb.Service.Contract.NonLife.SharedArtifacts.deploysequence.xml"
foreach($DeploySequenceXML in $DeploySequencelist){
    #clear All Variables for each application
	Write-Host "Deploy sequence XML - "$DeploySequenceXML
	$BiztalkApplicationName=$DeploySequenceName=""
	$GACAssemblies=$BizTalkReferences=$BiztalkBindings=$BizTalkResources=$NTServices=$ConfigFiles=$ConsoleApplications=$null
	
	#Common Config Directory
	$ConfigInstallDirectory=join-path $global:ESBRootFolder -ChildPath "Common\config\"
	$EaiCommonConfigDirectory=join-path $global:ESBRootFolder -ChildPath "Eai\config\"
	New-Item $ConfigInstallDirectory -ItemType Directory -Force | out-null
	New-Item $EaiCommonConfigDirectory -ItemType Directory -Force | out-null
	
	#Get Application Deployment Sequence XML and load XML sections
    if ($DeploySequenceXML.Attributes.Count -eq 0){
        $DeploySequenceXMLInnerText=$DeploySequenceXML
    }
    else{
        $DeploySequenceXMLInnerText=$DeploySequenceXML.InnerText
    }
	$DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
	$ApplicationDeploySequenceFile=[String]::Format("{0}\XML\{1}",$ESBDeploymentFolder,$DeploySequenceXMLInnerText)	
	$DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
	$ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
	
    $masterXPpath=[string]::Format("//DeployPackage[text()=""{0}""]",$DeploySequenceXMLInnerText)
    $DeployPackageNode=$MasterDeployXML.SelectSingleNode($masterXPpath)
    $CurrenApplicationDeployStatus=$DeployPackageNode.status
    if ([string]::IsNullOrEmpty($CurrenApplicationDeployStatus) -or ($CurrenApplicationDeployStatus -ne "Deployed")){
        AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -NewAttribute "status" -NewAttributeValue "Deploying"
		
		#get the Application Deployment folder for non Biztalk applicaiton
		$ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $DeploySequenceName
		$ApplicationPackageFolder=Join-Path $ESBDeploymentFolder -ChildPath $ApplicationShortName
		
		#Check and deploy scheduled tasks
        $ScheduledTasks=$DeploySequenceReader.SelectNodes("//Package.DeploySequence/SystemConfiguration/ScheduledTasks")
        if($ScheduledTasks.ChildNodes){
            if($($($ScheduledTasks.status) -ine "Deployed")){
                $ScheduledTask=$ScheduledTasks.ScheduledTask
                $TaskExeName=$($ScheduledTask.Action.program)
                $TaskName=$($ScheduledTask.name)
                $TaskPath=$(gci $ApplicationPackageFolder -recurse -filter $TaskExeName).FullName
                $TaskWorkingDirectory= Split-Path $TaskPath -Parent
                $UserID='BALGROUPIT\' + $($ScheduledTask.Creadentials.userName)
                $Password=$ScheduledTask.Creadentials.passWord
				
                If($ScheduledTasks){
                    RegisterScheduledTask -TaskExeName $TaskExeName -TaskWorkingDirectory $TaskWorkingDirectory -TaskPath $TaskPath -Environment $Environment -TaskName $TaskName -UserID $UserID -Password $Password
                }

                AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement "Package.DeploySequence/SystemConfiguration/ScheduledTasks" -NewAttribute "Status" -NewAttributeValue "Deployed"
            }
        }
        Elseif($($ScheduledTasks.status) -ieq "Deployed"){
            Write-Host "Scheduled Task is already installed..!"
        }
		
	    #getting the Biztalk Application Info
	    if($ApplicationConfiguration.ChildNodes){
			
			if($Platform -ieq "Eai"){
            $ApplicationPackageFolder=Join-Path $ESBDeploymentFolder -ChildPath $DeploySequenceName
            }
			
		    #Preparing the Appliction log Folder	
		    $Installlogfolder=Join-Path $Rootlogfolder -ChildPath $DeploySequenceName
		    New-Item $Installlogfolder -ItemType Directory -Force | Out-Null

		    Write-Host "===================================$($DeploySequenceName) Installation========================================================="
					
		    # Creating NT Services
		    $NTServices=$ApplicationConfiguration.SelectNodes("//NTServices")
		    if($NTServices.childnodes){
			    $ServiceLogFile=[String]::Format("{0}\InstallService_Log.txt",$Installlogfolder)
			    New-Item $ServiceLogFile -ItemType File -Force | Out-Null
	            Write-Host "`n -- START SERVICES --"	
	            foreach($Service in $($NTServices.NTService)){
				
					$ServiceDeploymentFolder=GetApplicationDeploymentFolder -ApplicationName $DeploySequenceName
					$ApplicationType="BizTalkServiceEsb"
					
					if($Platform -ieq "Eai"){
					$ServiceDeploymentFolder=$DeploySequenceName
					$ApplicationType="BizTalkServiceEai"
					}
	                
	                $ServiceName=$Service.GetElementsByTagName("NTServiceName").innerText
	                $ServcieDisplayName=$Service.GetElementsByTagName("NTServiceDisplayName").innerText
		            $ServiceExeName=$Service.GetElementsByTagName("NTServiceAssemblyName").innerText
		            $Serviceuser=$Service.GetElementsByTagName("NTServiceUserName").innerText
		            $ServicePassword=$Service.GetElementsByTagName("NTServiceUserPassword").innerText
					$InstallWithInstallUtil=$Service.NTServiceName.InstallWithInstallUtil
					$Service.NTServiceName.InstallWithInstallUtil
					Write-Host "Deployment folder name:" $ServiceDeploymentFolder
					
					if($InstallWithInstallUtil -ieq "True"){
					    Re-InstallWindowsService -ServiceName $ServiceName -ServiceDisplayName $ServcieDisplayName  -deploymentFolderName $ServiceDeploymentFolder -ServiceExeName $ServiceExeName -username $Serviceuser -password $ServicePassword -ApplicationType $ApplicationType -StartUpType "Automatic" -InstallWithInstallUtil $true  | Add-Content $ServiceLogFile -Force
					}
				    else{
		            # Installing and starting Windows Service
			        Write-Host "Installing: " $ServiceName
				        Re-InstallWindowsService -ServiceName $ServiceName -ServiceDisplayName $ServcieDisplayName  -deploymentFolderName $ServiceDeploymentFolder -ServiceExeName $ServiceExeName -username $Serviceuser -password $ServicePassword -ApplicationType $ApplicationType -StartUpType "Automatic" | Add-Content $ServiceLogFile -Force
		        	}
				}
			
	        }
	
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
	                    $ConfigFileName=$ConfigFile.GetElementsByTagName("FileName").innerText
	                    $configFileSourcePath=Get-ChildItem $ApplicationPackageFolder -Filter "*$($ConfigFileName)*" -Force -recurse
				        $ConfigDestination=$ConfigFile.GetElementsByTagName("Destination").innerText
	                    $ConfigJunctionSubdir=$ConfigFile.GetElementsByTagName("JunctionSubDirectory").innerText
		                if($ConfigDestination -ieq "ConfigSubDir"){
					        Write-host "Deploying CONFIG : " $ConfigFileName
	                        move-Item $configFileSourcePath.FullName -Destination $ConfigInstallDirectory -Force | add-content $ConfigLogFile -Force
	                    }
						
		                if($ConfigDestination -ieq "EaiCommonConfigDir"){
					        Write-host "Deploying CONFIG : " $ConfigFileName
	                        move-Item $configFileSourcePath.FullName -Destination $EaiCommonConfigDirectory -Force | add-content $ConfigLogFile -Force
	                    }
				
	                    if($ConfigJunctionSubdir -ieq "Config"){
	                        $JunctionDestination=join-path $ApplicationPackageFolder -ChildPath "config"
	                        CreateFolderJunction -JunctionDestination $JunctionDestination -JunctionSource $ConfigInstallDirectory -LogPath $ConfigLogFile
	                    }
						
						#Update MFT service configs on MFT servers only
						If(($ConfigFile -ilike "Mercator.Esb.Services.Mft.Service.exe*") -and ($ApplicationServerType -ieq "Mft")){
							UpdateHostPriorityLevel -ConfigFileName $ConfigFile -ApplicationShortName $ApplicationShortName
						}
                    }
                    #set Deployed flag
                    SetElementDeploymentSucceeded -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
                }
                else{
                    Write-Host "`n --CONFIG DEPLOYMENT already done--"	
		        }
	        }
			
		    
		
		    #Deploying Reference Assemblies
            $RootXPath="//ReferencedAssemblies"
		    $ReferenceAssemblies=$ApplicationConfiguration.SelectNodes("$RootXPath/Assembly")
		    if($ReferenceAssemblies.childnodes){
                #get Deploying flag
                $CurrenDeployStatus=$ApplicationConfiguration.SelectSingleNode("$RootXPath/DeployStatus").status
                if ([string]::IsNullOrEmpty($CurrenDeployStatus) -or ($CurrenDeployStatus -ne "Deployed")){
                    #set Deploying flag
                    AddElementDeploymentStarted -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
			        
			        $ReferenceDeployLogFile=[String]::Format("{0}\DeployReferenceAsssmblies_Log.txt",$Installlogfolder)	 
	                Write-Host "`n --REFERENCE ASSEMBLY DEPLOYMENT --"	
	                foreach($assembly in $ReferenceAssemblies){
				        $AssemblyName=$assembly.GetElementsByTagName("AssemblyName").innerText
				        $Destination=$assembly.GetElementsByTagName("Destination").innerText
				        $AddToGAC=$assembly.GetElementsByTagName("AddToGac").innerText
				        $AssemblyPath=Get-ChildItem $ApplicationPackageFolder -recurse -Filter "*.dll"| Where-Object {$_.Name -ieq $AssemblyName}
				        if($AddToGAC -ieq "true"){
					        Add-GAC  -AssemblyPath $AssemblyPath.FullName | Add-Content -Path $ReferenceDeployLogFile -Force
				        }
				        if($Destination -ine "bin"){
					        if($Destination.startswith("%") -and $Destination.endswith("%")){
						        $Destination=$Destination.replace("%","")
						        $Destination=[Environment]::GetEnvironmentVariable("$Destination", "Machine")
					        }
					        Write-host "Deploying Reference File : " $AssemblyPath.Name
					        Copy-Item $AssemblyPath.FullName -Destination $Destination -Force -ErrorAction Stop

				        }
			        }
                    #set Deployed flag
                    SetElementDeploymentSucceeded -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
                }
                else{
                    Write-Host "`n --REFERENCE ASSEMBLY DEPLOYMENT already done--"	
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
			
			if($ServerType -eq "Admin"){
            $RootXPath="//DatabaseServers"
		    $DatabaseServers=$ApplicationConfiguration.SelectNodes("$RootXPath/DatabaseServer")
		    if($DatabaseServers.childnodes){
                #get Deploying flag
                $CurrenDeployStatus=$ApplicationConfiguration.SelectSingleNode("$RootXPath/DeployStatus").status
                if ([string]::IsNullOrEmpty($CurrenDeployStatus) -or ($CurrenDeployStatus -ne "Deployed")){
                    #set Deploying flag
                    AddElementDeploymentStarted -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath

			        foreach($DatabaseServer in $DatabaseServers){
			        	Write-Host "`n --DATABASE DEPLOYMENT--"
			        	$DBServer=$DatabaseServer.GetElementsByTagName("DBServer").innerText
			        	$DBUser=$DatabaseServer.GetElementsByTagName("DBUser").innerText
			        	$DBPassword=$DatabaseServer.GetElementsByTagName("DBPassword").innerText
			        	$DBServerInstance=$DatabaseServer.GetElementsByTagName("DBServerInstance").innerText
			        	$DBServerInstancePort=$DatabaseServer.GetElementsByTagName("DBServerInstancePort").innerText
			        	$generatedScript=$DatabaseServer.GetElementsByTagName("DBServerInstancePort").generatedScript
			        	foreach($DBScript in $DatabaseServer.SqlcmdDBScripts.DBScript){
					        $DBScriptName=$DBScript.GetElementsByTagName("Name").innerText
				        	$DBName=$DBScript.databaseName
				        	$DBScriptFolder=join-path $ApplicationPackageFolder -ChildPath $DBName
				        	$DataBaseLogFile=[String]::Format("{0}\DB_{1}_{2}.txt",$Installlogfolder,$DBName,($DBScriptName.Replace(".sql","")))
							$dbEnvironment=$Environment
				        	#if($Environment -ieq "Dcorpbis"){
						    #    $dbEnvironment="DCORP"
				        	#}
				        	$DBScriptPath=Join-Path $DBScriptFolder -ChildPath $DBScriptName
				        	if($DBScript.generatedScript -ieq "true"){
						        $DBScriptPath=(get-childitem $DBScriptFolder  -Recurse -Force | where-object {$_.Name -ilike  "$($DBScriptName)"}).FullName
				        	}
				        	Write-Host "Deploying Script - $($DBScriptPath.Name) on $($DBName) Database "
							#Write-Host "Deploying Script - $([System.IO.Path]::GetFileName($DBScriptPath)) on $($DBName) Database "
				        	$SQLCommand=[string]::Format("sqlcmd -U {0}  -P {1}  -S {2} -i `"{3}`" -v DataBaseName={4} -v Path1 = `"E:\SQLData\MSSQL10.is0801\MSSQL\DATA\`" -v DefaultDataPath = `"E:\SQLData\MSSQL10.is0801\MSSQL\DATA\`" >> `"{5}`" ",$DBUser,$DBPassword,$DBServer,$DBScriptPath,$DBName,$DataBaseLogFile)
							write-host $SQLCommand
							cmd /c $SQLCommand
							if($LastExitCode -eq '0')
							{
								Write-Host "Database deployed successfully"
							}
							else{
								
								throw "Error in the database deployment. Last exit code: $LastExitCode"
								Exit 1
							}
			        	}
                    	#set Deployed flag
						SetElementDeploymentSucceeded -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
					}
                }
                else{
                    Write-Host "`n --DATABASE DEPLOYMENT already done--"	
                }
		    }
			}
		
		    New-PSDrive -Name "K" -PSProvider "FileSystem" -Root "$ApplicationPackageFolder" 
		
			#load all GAC assemblies
			$GacAssembliesPresent=$false
		    if($ApplicationConfiguration.GacAssemblies.ChildNodes){
				$GACAssemblies=$ApplicationConfiguration.SelectNodes("//GacAssemblies/Assembly/AssemblyName")
				$CurrenGacDeployStatus=$ApplicationConfiguration.SelectSingleNode("//GacAssemblies/DeployStatus").status
				$GacAssembliesPresent=$true
		    }
			#add assemblies pipeline assemblies to GAC
			$PipelineComponentsPresent=$false
			if($ApplicationConfiguration.BizTalkApplications.BizTalkApplication.PipelineComponents.ChildNodes){
				$GACAssemblies +=$ApplicationConfiguration.SelectNodes("//PipelineComponents/PipelineComponent/PipelineComponentName")
				$CurrenPipelineComponentDeployStatus=$ApplicationConfiguration.SelectSingleNode("//PipelineComponents/DeployStatus").status
				$PipelineComponentsPresent=$true
			}
			
		    if($GACAssemblies.childnodes){
				#get Deploying flag
				if ([string]::IsNullOrEmpty($CurrenGacDeployStatus) -or ($CurrenGacDeployStatus -ne "Deployed") -or [string]::IsNullOrEmpty($CurrenPipelineComponentDeployStatus) -or ($CurrenPipelineComponentDeployStatus -ne "Deployed") ){
					#set Deploying flag
					if ($GacAssembliesPresent) {AddElementDeploymentStarted -XmlPath $ApplicationDeploySequenceFile -ParentElement "//GacAssemblies" }
					if ($PipelineComponentsPresent) {AddElementDeploymentStarted -XmlPath $ApplicationDeploySequenceFile -ParentElement "//PipelineComponents" }

					$GACLogFile=[String]::Format("{0}\AddGAC_Log.txt",$Installlogfolder)	
					Write-Host "--- *** ADD GAC *** ---"
					ForEach($AssemblyName in $($GACAssemblies.innerText)){
						$AssemblyPath=gci "K:\" -recurse -Filter "*.dll"| ?{$_.Name -ieq $AssemblyName}
						ForEach($file in $($AssemblyPath.FullName)){
							Add-GAC  -AssemblyPath $file | Add-Content -Path $GACLogFile -Force
						}
					}
                    #set Deployed flag
					if ($GacAssembliesPresent) {SetElementDeploymentSucceeded -XmlPath $ApplicationDeploySequenceFile -ParentElement "//GacAssemblies" }
					if ($PipelineComponentsPresent) {SetElementDeploymentSucceeded -XmlPath $ApplicationDeploySequenceFile -ParentElement "//PipelineComponents" }
				}
				else{
					Write-Host "`n --GAC DEPLOYMENT already done--"	
				}
		    }
		    Remove-PSDrive -Name "K" -ErrorAction SilentlyContinue | Out-Null
		
			$RootXPath="//BizTalkApplications/BizTalkApplication"
	   	    $BiztalkApplications=$ApplicationConfiguration.BizTalkApplications.BizTalkApplication
		    if($BiztalkApplications.childnodes){
				$CurrenOverallDeployStatus=$BiztalkApplications.overallStatus
				$BiztalkApplicationName=$BiztalkApplications.BizTalkApplicationName
				if ([string]::IsNullOrEmpty($CurrenOverallDeployStatus) -or ($CurrenOverallDeployStatus -ne "Deployed") ){
					#set Deploying flag
					AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath -NewAttribute "overallStatus" -NewAttributeValue "Deploying"
					#get the Biztalk Application Deployment Folder Name
					$ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $BiztalkApplicationName
					$ApplicationPackageFolder=Join-Path $ESBDeploymentFolder -ChildPath $ApplicationShortName
					if($Platform -ieq "Eai"){
            			$ApplicationPackageFolder=Join-Path $ESBDeploymentFolder -ChildPath $DeploySequenceName
            		}
				
					New-PSDrive -Name "K" -PSProvider "FileSystem" -Root "$ApplicationPackageFolder" -ErrorAction SilentlyContinue | Out-Null
				
					if($ServerType -eq "Admin"){
						# Create BTS Application
						$CreateAppLogFile=[String]::Format("{0}\CreateBTSApplication_Log.txt",$Installlogfolder)
						$createApplicationStatus=$BiztalkApplications.createApplicationStatus
						if ([string]::IsNullOrEmpty($createApplicationStatus) -or ($createApplicationStatus -ne "Deployed") ){
							#set Deploying flag
							AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement "$RootXPath" -NewAttribute "createApplicationStatus" -NewAttributeValue "Deploying"
							Write-Host "--- *** CREATE APPLICATION *** ---"
							Create-BTSApplication -ApplicationName $BiztalkApplicationName | Add-Content -Path $CreateAppLogFile -Force
							#set Deployed flag
							SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement "$RootXPath" -Attribute "createApplicationStatus" -NewAttributeValue "Deployed"
						}
						else{
							Write-Host "`n --application $BiztalkApplicationName already created--"	
						}

						# Adding Refrences to the application
						$BizTalkReferences=$BiztalkApplications.selectNodes("//BizTalkReferences//BizTalkReference")
						if($BizTalkReferences){
							Write-Host "--- *** ADD REFERENCES *** ---"
							$InstallFolder=[String]::Format("{0}\AddReferences_Log.txt",$Installlogfolder)
							New-Item $InstallFolder -ItemType File -Force |Out-Null

                            #for quick fix, add reference to new bts application Mercator.Esb.Framework.Services.1.0 by default
                            if ( ($BiztalkApplicationName -ine "Mercator.Esb.Framework.Services.1.0") -and ($BiztalkApplicationName -ine "Mercator.Esb.Framework.1.0") ){
                                Add-References -ApplicationName $BiztalkApplicationName -Reference "Mercator.Esb.Framework.Services.1.0" | Tee-Object -FilePath $InstallFolder -Append
                            }
							

							ForEach($BizTalkReference in $BizTalkReferences){
								$Reference=$BizTalkReference.InnerText
								$xpath=[string]::Format("//BizTalkReferences//BizTalkReference[text()=""{0}""]",$Reference)
								$addReferenceStatus=$BizTalkReference.status
								if ([string]::IsNullOrEmpty($addReferenceStatus) -or ($addReferenceStatus -ne "Deployed") ){
									#set Deploying flag
									AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement $xpath -NewAttribute "status" -NewAttributeValue "Deploying"
									"Adding Reference : $Reference" | Tee-Object -FilePath $InstallFolder -Append
									Add-References -ApplicationName $BiztalkApplicationName -Reference $Reference | Tee-Object -FilePath $InstallFolder -Append
									#set Deployed flag
									SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement "$xpath" -Attribute "status" -NewAttributeValue "Deployed"
								}
								else{
									Write-Host "`n --reference $Reference already added--"	
								}
							}
						}
						else{
							Write-Host "WARNING: No References found.."|Tee-Object -Path $InstallFolder
						}		

						# Add BizTalk Resources
						$BizTalkResources=@()
						$BizTalkResources=$BiztalkApplications.selectNodes("//BizTalkResource//BizTalkResourceName")
						if($BizTalkResources){
							$InstallFolder=[String]::Format("{0}\AddResources_Log.txt",$Installlogfolder)
							Write-Host "--- *** ADD RESOURCES *** ---"		
							ForEach($BizTalkResource in $BizTalkResources){
								$Resource=$BizTalkResource.InnerText
								$Resourcepath=gci "K:\" -recurse -Filter "*.dll" | ?{$_.Name -ieq $Resource}
								$xpath=[string]::Format("//BizTalkResource//BizTalkResourceName[text()=""{0}""]",$Resource)
								$addResourceStatus=$BizTalkResource.status
								if([string]::IsNullOrEmpty($addResourceStatus) -or ($addResourceStatus -ne "Deployed") ){
									#set Deploying flag
									AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement $xpath -NewAttribute "status" -NewAttributeValue "Deploying"
									ForEach($file in $Resourcepath){										
										Add-Resources -ApplicationName $BiztalkApplicationName -ResourcePath $file.FullName | Add-Content -Path $InstallFolder -Force
									}	
									#set Deployed flag
									SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $xpath -Attribute "status" -NewAttributeValue "Deployed"
								}
								else{
									Write-Host "`n --Resource $Resource already added--"	
								}
							}
						}
					
						# Import BizTalk Binding File
						$BiztalkBindings=$BiztalkApplications.selectNodes("//BindingFiles//BindingFile").innertext						
						if($BiztalkBindings){
							$addBindingStatus=$BiztalkApplications.selectNodes("//BindingFiles//BindingFile").status
							$xpath=[string]::Format("//BindingFiles//BindingFile[text()=""{0}""]",$BiztalkBindings)
							if([string]::IsNullOrEmpty($addBindingStatus) -or ($addBindingStatus -ne "Deployed") ){
								#set Deploying flag
								AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement $xpath -NewAttribute "status" -NewAttributeValue "Deploying"
								$InstallFolder=[String]::Format("{0}\ImportBindings_Log.txt",$Installlogfolder)
								Write-Host "--- *** IMPORT BINDING *** ---"	
								$BindingFilePath=gci "K:\" -recurse -Filter "*.xml"| where-Object{$_.Name -ieq $BiztalkBindings}
								Import-BindingFile -ApplicationName $BiztalkApplicationName -BindingFilePath $($BindingFilePath.FullName) | Add-Content -Path $InstallFolder -Force
								#set Deployed flag
								SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $xpath -Attribute "status" -NewAttributeValue "Deployed"
							}
							else{
								Write-Host "`n --BiztalkBinding $BiztalkBinding already added--"	
							}
						}

						$BREpolicies=$ApplicationConfiguration.SelectNodes("//BusinessRuleEngine/Policies/Policy")
						if($BREpolicies.ChildNodes){
							Write-Host "`n --DEPLOYING BUISNESS RULE ENGINE--"	
							$BREInstallationLogFile=[String]::Format("{0}\BREDeployment_Log.txt",$Installlogfolder)
							foreach($policy in $BREpolicies){
								$breDeployStatus=$BiztalkApplications.selectNodes("//BusinessRuleEngine/Policies/Policy").status
								$BREFileName=$policy.GetElementsByTagName("PolicyName").innerText 
								$BREVersion=$policy.GetElementsByTagName("PolicyVersion").innerText
								$BREFile=get-childitem $ApplicationPackageFolder  -force -Recurse -Filter "$($BREFileName)"
								$xpath=[string]::Format("//BusinessRuleEngine//Policies//Policy//PolicyName[text()=""{0}""]",$BREFileName)
								if([string]::IsNullOrEmpty($breDeployStatus) -or ($breDeployStatus -ne "Deployed") ){
									#set Deploying flag
									AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement $xpath -NewAttribute "status" -NewAttributeValue "Deploying"
									#do BRE deployment
									DeployBRE -BREFilePath $BREFile -BREVersion $BREVersion -BRELogile $BREInstallationLogFile
									#set Deployed flag
									SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $xpath -Attribute "status" -NewAttributeValue "Deployed"
								}
								else{
									Write-Host "`n --BRE $BREFileName already deployed--"	
								}
							}
						}
					}
					else{
                        #if non admin server, GAC all BizTalk assemblies
						$GACAssemblies=$BiztalkApplications.selectNodes("//BizTalkResource//BizTalkResourceName")
						if($GACAssemblies){
							$GACLogFile=[String]::Format("{0}\AddGAC_Log.txt",$Installlogfolder)	
							Write-Host "--- *** ADD GAC *** ---"
							ForEach($AssemblyName in $($GACAssemblies.innerText)){
								$AssemblyPath=gci "K:\" -recurse| ?{!($_.PSISContainer) -and ($_.Name -ieq $AssemblyName)}
								ForEach($file in $($AssemblyPath.FullName)){
									Add-GAC  -AssemblyPath $file | Add-Content -Path $GACLogFile -Force
								}
							}
						}						
					}
					Remove-PSDrive -Name "K" -ErrorAction SilentlyContinue | Out-Null
					#set Deployed flag
					SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement "$RootXPath" -Attribute "overallStatus" -NewAttributeValue "Deployed"
				}	
				else{
					Write-Host "`n --application $BiztalkApplicationName already deployed--"	
				}
			}

			#getting Console applications 
            $RootXPath="//ConsoleApplications"
		    $ConsoleApplications=$ApplicationConfiguration.SelectNodes("$RootXPath/ConsoleApplication")
		    if($ConsoleApplications.ChildNodes){
                #get Deploying flag
                $CurrenDeployStatus=$ApplicationConfiguration.SelectSingleNode("$RootXPath/DeployStatus").status
                if ([string]::IsNullOrEmpty($CurrenDeployStatus) -or ($CurrenDeployStatus -ne "Deployed")){
                    #set Deploying flag
                    AddElementDeploymentStarted -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
			        $ConsoleFile=[String]::Format("{0}\DeployConsoleApp_Log.txt",$Installlogfolder)	 
	                Write-Host "`n --CONSOLE APPLICATION DEPLOYMENT --"	
	                foreach($ConsoleApplication in $ConsoleApplications){
	                    $ConsoleAppName=$ConsoleApplication.GetElementsByTagName("ApplicationName").innerText
				        $RunCmdAtDeployTime=$ConsoleApplication.GetElementsByTagName("RunCmdAtDeployTime").innerText
	                    $ConfigJunctionSubdir=$ConsoleApplication.GetElementsByTagName("JunctionSubDirectory").innerText
				        $CmdFilename=$ConsoleApplication.GetElementsByTagName("FileName").innerText
				        $ConsoleAppExeFolderPath=Get-ChildItem $ApplicationPackageFolder -Filter "$($ConsoleAppName)" -Force -recurse
				        $ConsoleAppExeFolderPath=Split-Path $ConsoleAppExeFolderPath.FullName -Parent
				        $junctionDestination=join-path $ConsoleAppExeFolderPath -ChildPath "config"
	                    if($ConfigJunctionSubdir -ieq "Config"){
					        CreateFolderJunction -JunctionDestination $JunctionDestination $junctionDestination -JunctionSource $ConfigInstallDirectory -LogPath $ConsoleFile
	                    }
				        if($RunCmdAtDeployTime -ieq "True"){
					        Write-host "RUNNING CMD : " $CmdFilename 
					        Set-Location $ConsoleAppExeFolderPath -ErrorAction Stop 
					        $CosnsoleExePath=[string]::Format('"{0}" > "{1}"',(Join-Path $ConsoleAppExeFolderPath -ChildPath $CmdFilename), $ConsoleFile)
					        cmd /c "$CosnsoleExePath" 
				        }
		            }
                    #set Deployed flag
                    SetElementDeploymentSucceeded -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath
                }
                else{
                    Write-Host "`n --CONSOLE APPLICATION DEPLOYMENT already done--"	
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

                        $AssemblyPath=Get-ChildItem $ESBDeploymentFolder  -recurse| ?{!($_.PSISContainer) -and ($_.Name -ieq $ComPlusComponent.AssemblyName)}
                        Create-ComPlus -assemblyName $AssemblyPath.FullName -targetApplication $ComPlusComponent.ComPlusName -identity $ComPlusComponent.ComPlusIdentity -pswd $ComPlusComponent.ComPlusPassword -runForever $ComPlusComponent.ComPlusRunForEver
                                              
                        if ($ComPlusComponent.Components.ChildNodes){
                            $ComponentName=$ComPlusComponent.Components.Component.ComponentName.InnerText
                            $ConstructorString=$ComPlusComponent.Components.Component.ConstructorString
                            Set-ComPlusConstructorString -targetApplication $ComPlusComponent.ComPlusName -targetComponent $ComponentName -constructorString $ConstructorString
                        }

                        #set Deployed flag
                        SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $RootXPath -Attribute "ComPlusStatus" -NewAttributeValue "Deployed"


                    }
                    else{
                        Write-Host "`n --COM+ already deployed--"	
		            }
                }
	        }
			
			#Reconfigure Dynamic SendPorts
			if($ServerType -ieq "Admin"){
	            $RootXPath="//ReconfigureDynamicSendPorts/SendPort"
		   	    $DynamicSendPorts=$ApplicationConfiguration.ReconfigureDynamicSendPorts.SendPort
			    if($DynamicSendPorts.ChildNodes){
	                
	                foreach($DynamicSendPort in $DynamicSendPorts){
	                
	                    #get Deploying flag
	                    $xpath=[string]::Format("{0}[@name=""{1}""]",$RootXPath, $DynamicSendPort.name)
	                    $CurrenDeployStatus=$ApplicationConfiguration.SelectSingleNode("$xpath").DynamicSendPortsStatus
	                    if ([string]::IsNullOrEmpty($CurrenDeployStatus) -or ($CurrenDeployStatus -ne "Deployed")){
	                        #set Deploying flag
	                        AddAttributeToElement -XmlPath $ApplicationDeploySequenceFile -ParentElement $xpath -NewAttribute "DynamicSendPortsStatus" -NewAttributeValue "Deploying"

	                        $name=$DynamicSendPort.name
	                        $adapter=$DynamicSendPort.ConfigureSendHandler.adapter
	                        $sendHandler=$DynamicSendPort.ConfigureSendHandler.SendHandler
							sleep -Seconds $Global:TimeOut
	                        Reconfigure-DynamicSendPort -sendPortName $name -adapter $adapter -sendHandler $sendHandler

	                        #set Deployed flag
	                        SetAttribute -XmlPath $ApplicationDeploySequenceFile -ParentElement $xpath -Attribute "DynamicSendPortsStatus" -NewAttributeValue "Deployed"
	                    }
	                    else{
	                        Write-Host "`n --send port $($DynamicSendPort.name) already reconfigured--"	
			            }
	                }
		        }
			}
		    Write-Host "===================================$($DeploySequenceName) End Installation========================================================="
			
		}
	    else{
		    Write-host "Application Components not found : " $DeploySequenceName
	    }

        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "Deployed"
    }
    elseif ($CurrenApplicationDeployStatus -eq "Deployed"){
        Write-Host "$DeploySequenceName deployment already done."
    }
}

# RESTORE CDM FOLDER
if($Platform -ieq "Esb"){
	$CdmBackupFolder="E:\Cdm_Backup"
	$PortalCDMFolder=[String]::Format("{0}\Portal\Content\Cdm",$ESBDeploymentFolder)
	Write-Host "CDM Backup Folder:"$CdmBackupFolder
	Write-Host "Portal Cdm Folder:"$PortalCDMFolder
	
	New-Item $PortalCDMFolder -ItemType Directory -Force|Out-Null
	
	Copy "$CdmBackupFolder\*" -Destination "$PortalCDMFolder\" -Force -recurse
}

# RESTORE FUNCTIONAL DESIGN FOLDER
$FunctionalDesignBackupFolder="E:\Backup\FuntionalDesign_Backup"
$FunctionalDesignFolder=[String]::Format("{0}\Portal\Content\FunctionalDesign",$ESBDeploymentFolder)

if(Test-Path $FunctionalDesignBackupFolder){
    New-Item $FunctionalDesignFolder -Itemtype Directory -Force |Out-Null
    Copy-Item "$FunctionalDesignBackupFolder\*" -Destination "$FunctionalDesignFolder\" -Force -Recurse
}
Else{
    Write-Host "INFO: Functional design folder does not exist in backup folder."
}

#deployment ok, update 
SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "Deployed"
#>