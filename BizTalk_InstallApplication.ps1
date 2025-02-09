Param
(
[String]$ServerType="admin",
[String]$Environment="dcorpbis"
)
Clear-host

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

#Getting the Package to be Deployed
$BuildVersion=gci Filesystem::"\\svw-be-bldp002\EsbPackages\" -filter "*1.29.2018*" | sort LastWriteTime -desc  |select -first 1
$BuildVersion=$($BuildVersion.Name)
$PackageFolder= [String]::Format("\\svw-be-bldp002\EsbPackages\{0}",$BuildVersion)
if(-not (Test-Path $PackageFolder)){
	Write-Host "Package Not found : " $PackageFolder
	Exit 1
}


$ESBDeploymentFolder=Join-Path $global:ESBRootFolder -ChildPath "Esb"
$Rootlogfolder=[String]::Format("{0}\Logs\Install_{1}",$ESBDeploymentFolder,(Get-Date -Format yyyyMMdd-hhmmss))
$DeployStatusFile=Join-Path $ESBDeploymentFolder -ChildPath "DeployStatus.xml"
if (Test-Path $DeployStatusFile){
	Write-Host "DeployStatus.xml found."
}
else{
    CreateDeployStatusXML $ESBDeploymentFolder
}
$DeployStatusXML=[xml] (get-content filesystem::$DeployStatusFile -Force )

#Deploying the Package on the server
if ($DeployStatusXML.DeployStatus.DeployPackage.status -ne "Succeeded"){
Write-Host "Deploying Package : " $BuildVersion
    New-Item $ESBDeploymentFolder -ItemType Directory  -Force| Out-Null
    cmd /c "net use K: $PackageFolder"
    Copy-Item "K:\*" -destination $ESBDeploymentFolder -Force -Recurse
    cmd /c "net use K: /d /y"
    #add succeeded to DeployStatusXML
    AddElementWithAttributeToXml -DeployStatusPath $DeployStatusFile -ParentElement "DeployStatus" -NewElementName "DeployPackage" -NewAttribute "status" -NewAttributeValue "Succeeded"
}
else{
    Write-Host "Package : " $BuildVersion " was already deployed."
}

#Setting the Configuration based on the environment
if ($DeployStatusXML.DeployStatus.DeployConfig.status -ne "Succeeded"){
    $paramxmlfilepath=Join-Path $ESBDeploymentFolder -ChildPath "ESBDeploymentParameters_Resolved.xml"
    ConfigDeployer -ParameteXMLFile $paramxmlfilepath -Environment $Environment -DeploymentFolder $ESBDeploymentFolder
    #add succeeded to DeployStatusXML
    AddElementWithAttributeToXml -DeployStatusPath $DeployStatusFile -ParentElement "DeployStatus" -NewElementName "DeployConfig" -NewAttribute "status" -NewAttributeValue "Succeeded"
}
else{
    Write-Host "Configuration was already deployed."
}

#Reading the Master Deploy Sequence
$DeploymentxmlDirectory=join-path $ESBDeploymentFolder -ChildPath "XML"
$ESBMasterDeploySequencePath=join-path $DeploymentxmlDirectory  "Mercator.Esb.Master.DeploySequence.xml"
$MasterDeployXML=[xml] (get-content filesystem::$ESBMasterDeploySequencePath -Force )
$overallDeployStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.deployStatus
if ([string]::IsNullOrEmpty($overallDeployStatus)){
    AddAttributeToElement -XmlPath $ESBMasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -NewAttribute "deployStatus" -NewAttributeValue "DeploymentStarted"
}
elseif ($overallDeployStatus -eq "DeploymentSucceeded"){
    Write-Host "Deployment already succeeded."
    Exit 1
}

$DeploySequencelist=$MasterDeployXML.'Master.DeploySequence'.'DeployPackages.DeploySequence'.DeployPackage 
#$DeploySequencelist="Mercator.Esb.Database.DeploySequence.xml"
#$DeploySequencelist="Mercator.Esb.Framework.DeploySequence.xml"
#$DeploySequencelist="Mercator.Esb.Load.Test.DeploySequence.xml"

# Prerequisites setup
$PrerequisitesDeployStatus=$MasterDeployXML.'Master.DeploySequence'.Prerequisites.deployStatus
if ([string]::IsNullOrEmpty($PrerequisitesDeployStatus) -or ($PrerequisitesDeployStatus -ne "DeploymentSucceeded")){
    AddAttributeToElement -XmlPath $ESBMasterDeploySequencePath -ParentElement "Master.DeploySequence/Prerequisites" -NewAttribute "deployStatus" -NewAttributeValue "DeploymentStarted"

    $PreRequisiteName=$MasterDeployXML.'Master.DeploySequence'.Prerequisites.Prerequisite
    #  BizTalk Application
    $BizTalkApp=$PreRequisiteName.BiztalkApplication.Name
    Write-Host "`n -- CHECKING PRE_REQUISITE BIZTALK APPLICATIONS --"
    ForEach($app in $BizTalkApp)
    {
        $SearchResult=$global:BtsCatalogExplorer.Applications | ?{$_.Name -imatch $app}
	    Write-Host "Application :" $app
	    if(!$SearchResult.Name){
            Write-Error "NOT FOUND : " $app
            Exit 1
        }
    }

    # System Variable
    $SystemVariables=$PreRequisiteName.SystemVariables.SystemVariable
    Write-Host "`n -- ADDING ENVIRONMENT VARIABLES --"
    ForEach($Variable in $SystemVariables){
        Write-Host "Variable Name :"$Variable.name
        Write-Host "Variable Value:"$Variable.value
        if(![Environment]::GetEnvironmentVariable($($Variable.name),"Machine")){
		    [Environment]::SetEnvironmentVariable($($Variable.name),$($Variable.value),"Machine")
	    }
    }


    # Certificate Store
    if($($PreRequisiteName.Certificate).ChildNodes)
    {
        $CertificateStoreDeploymentDirectory= join-path $global:ESBRootFolder -childpath "CertificateStore\"
	    $CertificateStorePackageSource=[String]::Format("{0}\CertificateStore\",$ESBDeploymentFolder)
	
        ForEach($Certificate in $PreRequisiteName.Certificate){
		    $CertificateDeploymentFolder=Join-Path $CertificateStoreDeploymentDirectory -ChildPath $($Certificate.Name)
		    new-item $CertificateDeploymentFolder -ItemType directory -Force | Out-Null
		    ForEach($file in $Certificate.File)
            {
        	    $CertificateFile=Get-ChildItem $CertificateStorePackageSource -Filter "$($file.Name)" -Recurse -Force
			    if(!$CertificateFile.FullName){
        	      Write-Host "CERTIFICATE NOT FOUND : " $file.Name
			      Exit 1
			    }
			
			    Copy-Item $CertificateFile.FullName -Destination $CertificateDeploymentFolder -Force
		    }
            $CertificateStoreSubDirectory=[String]::Format("{0}\{1}",$CertificateStoreRootDirectory,$Folder)
	       }
    }

    SetAttribute -XmlPath $ESBMasterDeploySequencePath -ParentElement "Master.DeploySequence/Prerequisites" -Attribute "deployStatus" -NewAttributeValue "DeploymentSucceeded"
}
elseif ($PrerequisitesDeployStatus -eq "DeploymentSucceeded"){
    Write-Host "Prerequisites deployment already succeeded."
}


foreach($DeploySequenceXML in $DeploySequencelist){
    #clear All Variables for each application
	$BiztalkApplicationName=$DeploySequenceName=""
	$GACAssemblies=$BizTalkReferences=$BiztalkBindings=$BizTalkResources=$NTServices=$ConfigFiles=$ConsoleApplications=$null
	
	#Common Config Directory
	$ConfigInstallDirectory=join-path $global:ESBRootFolder -ChildPath "Common\config\"
	New-Item $ConfigInstallDirectory -ItemType Directory -Force | out-null
	
	#Get Application Deployment Sequence XML and load XML sections
    if ($DeploySequenceXML.Attributes.Count -eq 0){
        $DeploySequenceXMLInnerText=$DeploySequenceXML
    }
    else{
        $DeploySequenceXMLInnerText=$DeploySequenceXML.InnerText
    }
	$DeploySequenceName=$DeploySequenceXMLInnerText-ireplace ".DeploySequence.xml",""
	$ApplicationDeploySequenceFile=[String]::Format("{0}\XML\{1}",$ESBDeploymentFolder,$DeploySequenceXMLInnerText)	
	$DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
	$ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration

    $xpath=[string]::Format("//DeployPackage[text()=""{0}""]",$DeploySequenceXMLInnerText)
    $DeployPackageNode=$MasterDeployXML.SelectSingleNode($xpath)
    $CurrenApplicationDeployStatus=$DeployPackageNode.deployStatus
    if ([string]::IsNullOrEmpty($CurrenApplicationDeployStatus) -or ($CurrenApplicationDeployStatus -ne "DeploymentSucceeded")){
        AddAttributeToElement -XmlPath $ESBMasterDeploySequencePath -ParentElement $xpath -NewAttribute "deployStatus" -NewAttributeValue "DeploymentStarted"
	
	    #getting the Biztalk Application Info
	    if($ApplicationConfiguration.ChildNodes){
	
		    #get the Application Deployment folder for non Biztalk applicaiton
		    $ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $DeploySequenceName
		    $ApplicationPackageFolder=Join-Path $ESBDeploymentFolder -ChildPath $ApplicationShortName
		
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
	            foreach($Service in $NTServices){
	                $ServiceDeploymentFolder=GetApplicationDeploymentFolder -ApplicationName $DeploySequenceName
	                $ServiceName=$Service.GetElementsByTagName("NTServiceName").innerText
	                $ServcieDisplayName=$Service.GetElementsByTagName("NTServiceDisplayName").innerText
		            $ServiceExeName=$Service.GetElementsByTagName("NTServiceAssemblyName").innerText
		            $Serviceuser=$Service.GetElementsByTagName("NTServiceUserName").innerText
		            $ServicePassword=$Service.GetElementsByTagName("NTServiceUserPassword").innerText
				    Write-Host "Deployment folder name:" $ServiceDeploymentFolder
				
		            # Installing and starting Windows Service
			        Write-Host "Installing: " $ServiceName
				        Re-InstallWindowsService -ServiceName $ServiceName -ServiceDisplayName $ServcieDisplayName  -deploymentFolderName $ServiceDeploymentFolder -ServiceExeName $ServiceExeName -username $Serviceuser -password $ServicePassword -ApplicationType "BizTalkService" -StartUpType "Automatic" | Add-Content $ServiceLogFile -Force
		        }
			
	        }
	
		
		    #getting Config Files 
		    $ConfigFiles=$ApplicationConfiguration.SelectNodes("//ConfigFiles/ConfigFile")
		    if($ConfigFiles.ChildNodes){
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
				
	                if($ConfigJunctionSubdir -ieq "Config"){
	                    $JunctionDestination=join-path $ApplicationPackageFolder -ChildPath "config"
	                    CreateFolderJunction -JunctionDestination $JunctionDestination -JunctionSource $ConfigInstallDirectory -LogPath $ConfigLogFile
	                }
		        }
	        }
			
		    #getting Console applications 
		    $ConsoleApplications=$ApplicationConfiguration.SelectNodes("//ConsoleApplications/ConsoleApplication")
		    if($ConsoleApplications.ChildNodes){
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
					    Set-Location $ConsoleAppExeFolderPath  
					    $CosnsoleExePath=[string]::Format('"{0}" >> "{1}"',(Join-Path $ConsoleAppExeFolderPath -ChildPath $CmdFilename), $ConsoleFile)
					    cmd /c $CosnsoleExePath 
				    }
		        }
	        }
		
		    #Deploying Reference Assemblies
		    $ReferenceAssemblies=$ApplicationConfiguration.SelectNodes("//ReferencedAssemblies/Assembly")
		    if($ReferenceAssemblies.childnodes){
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
					    Copy-Item $AssemblyPath.FullName -Destination $Destination -Force

				    }
			    }
		    }

		    $DeploymentFiles=$ApplicationConfiguration.SelectNodes("//DeploymentFiles/Folders/Folder[@destinationType='Remote']")
		    if($DeploymentFiles){
	            Write-Host "`n --Deploy Remote Folders--"	
	            foreach($Folder in $DeploymentFiles){
				    $sourceSubpath=$($Folder.tfsPath).Replace("/","`\")
				    $sourceFolder=[string]::Format("{0}\Remote\{1}\",$ApplicationPackageFolder, $sourceSubpath)
				    $Destination=$Folder.GetElementsByTagName("Destination").innerText
				    Copy-Item "$($sourceFolder)*" -Destination $Destination -Force -Recurse 
				    }
			    }
		    $DatabaseServers=$ApplicationConfiguration.SelectNodes("//DatabaseServers/DatabaseServer")
		    if($DatabaseServers){
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
				    $DataBaseLogFile=[String]::Format("{0}\DB_{1}.txt",$Installlogfolder,$DBName)
				    if($Environment -ieq "Dcorpbis"){
					    $dbEnvironment="DCORP"
				    }
				    $DBScriptPath=Join-Path $DBScriptFolder -ChildPath $DBScriptName
				    if($DBScript.generatedScript -ieq "true"){
					    $DBScriptPath=(get-childitem $DBScriptFolder  -Recurse -Force | where-object {$_.Name -ilike  "*$($dbEnvironment)$($DBScriptName)"}).FullName
				    }
				    Write-Host "Deploying Script - $($DBScriptPath.Name) on $($DBName) Database "
				    $SQLCommand=[string]::Format("sqlcmd -U {0}  -P {1}  -S {2} -i `"{3}`" -v DataBaseName={4} -v Path1 = `"E:\SQLData\MSSQL10.is0801\MSSQL\DATA\`" -v DefaultDataPath = `"E:\SQLData\MSSQL10.is0801\MSSQL\DATA\`" >> `"{5}`" ",$DBUser,$DBPassword,$DBServer,$DBScriptPath,$DBName,$DataBaseLogFile)
				    cmd /c $SQLCommand
				    }
			    }
		    }	
		
		    New-PSDrive -Name "K" -PSProvider "FileSystem" -Root "$ApplicationPackageFolder" -ErrorAction SilentlyContinue | Out-Null
		
		    #load all GAC assemblies
		    if($ApplicationConfiguration.GacAssemblies.ChildNodes){
			    $GACAssemblies=$ApplicationConfiguration.SelectNodes("//GacAssemblies/Assembly/AssemblyName")
		    }
		    #add assemblies pipeline assemblies to GAC
		    $GACAssemblies +=$ApplicationConfiguration.SelectNodes("//PipelineComponents/PipelineComponent")
		    if($GACAssemblies){
			    $GACLogFile=[String]::Format("{0}\AddGAC_Log.txt",$Installlogfolder)	
		        Write-Host "--- *** ADD GAC *** ---"
		        ForEach($AssemblyName in $($GACAssemblies.innerText)){
			        $AssemblyPath=gci "K:\" -recurse -Filter "*.dll"| ?{$_.Name -ieq $AssemblyName}
			        ForEach($file in $($AssemblyPath.FullName)){
		    	        Add-GAC  -AssemblyPath $file | Add-Content -Path $GACLogFile -Force
			        }
		        }
		    }
		    Remove-PSDrive -Name "K" -ErrorAction SilentlyContinue | Out-Null
		
	   	    $BiztalkApplications=$ApplicationConfiguration.BizTalkApplications.BizTalkApplication
		    if($BiztalkApplications){
			    $BiztalkApplicationName=$BiztalkApplications.BizTalkApplicationName
			    #get the Biztalk Application Deployment Folder Name
			    $ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $BiztalkApplicationName
			    $ApplicationPackageFolder=Join-Path $ESBDeploymentFolder -ChildPath $ApplicationShortName
			
			    New-PSDrive -Name "K" -PSProvider "FileSystem" -Root "$ApplicationPackageFolder" -ErrorAction SilentlyContinue | Out-Null
			
			    if($ServerType -eq "Admin"){
				
				    # Create BTS Application
				    $CreateAppLogFile=[String]::Format("{0}\CreateBTSApplication_Log.txt",$Installlogfolder)
				    Write-Host "--- *** CREATE APPLICATION *** ---"
				    Create-BTSApplication -ApplicationName $BiztalkApplicationName | Add-Content -Path $CreateAppLogFile -Force
				
				    # Add BizTalk Resources
				    $BizTalkResources=@()
				    $BizTalkResources=$BiztalkApplications.selectNodes("//BizTalkResource//BizTalkResourceName")
				    if($BizTalkResources){
			    	    $InstallFolder=[String]::Format("{0}\AddResources_Log.txt",$Installlogfolder)
			    	    Write-Host "--- *** ADD RESOURCES *** ---"		
			    	    ForEach($Resource in $BizTalkResources.innerText){
				    	    $Resourcepath=gci "K:\" -recurse -Filter "*.dll" | ?{$_.Name -ieq $Resource}
				    	    ForEach($file in $Resourcepath){
						        Add-Resources -ApplicationName $BiztalkApplicationName -ResourcePath $file.FullName | Add-Content -Path $InstallFolder -Force
				    	    }	
			    	    }
				    }
			    
				
				    # Adding Refrences to the application
			
				    $BizTalkReferences=$BiztalkApplications.selectNodes("//BizTalkReferences//BizTalkReference")
				    if($BizTalkReferences){
					
					
					    Write-Host "--- *** ADD REFERENCES *** ---"
					    $InstallFolder=[String]::Format("{0}\AddReferences_Log.txt",$Installlogfolder)
					    New-Item $InstallFolder -ItemType File -Force |Out-Null
					    ForEach($Reference in $BizTalkReferences.innerText){
						"Adding Reference : $Reference" | Tee-Object -FilePath $InstallFolder -Append
			    		    Add-References -ApplicationName $BiztalkApplicationName -Reference $Reference | Tee-Object -FilePath $InstallFolder -Append
					    }
					
				    }
				    else{
					    Write-Host "WARNING: No References found.."|Tee-Object -Path $InstallFolder
				    }
				
				
				    # Import BizTalk Binding File
				    $BiztalkBindings=$BiztalkApplications.selectNodes("//BindingFiles//BindingFile").innertext
				    if($BiztalkBindings){
					    $InstallFolder=[String]::Format("{0}\ImportBindings_Log.txt",$Installlogfolder)
					    Write-Host "--- *** IMPORT BINDING *** ---"	
					    $BindingFilePath=gci "K:\" -recurse -Filter "*.xml"| where-Object{$_.Name -ieq $BiztalkBindings}
					    Import-BindingFile -ApplicationName $BiztalkApplicationName -BindingFilePath $($BindingFilePath.FullName) | Add-Content -Path $InstallFolder -Force
				    }
				
				
			    }
			    else{
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
			    }			
		    Write-Host "===================================$($DeploySequenceName) Installation========================================================="
	    }
	    else{
		    Write-host "Application Components not found : " $DeploySequenceName
	    }

        SetAttribute -XmlPath $ESBMasterDeploySequencePath -ParentElement $xpath -Attribute "deployStatus" -NewAttributeValue "DeploymentSucceeded"
    }
    elseif ($CurrenApplicationDeployStatus -eq "DeploymentSucceeded"){
        Write-Host "Prerequisites deployment already succeeded."
    }
}
