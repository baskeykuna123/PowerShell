Param($PatchNumber,$Platform,$ReleaseID,$ServerType,$Environment)

Clear;
#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

# Test input parameters
If(!$PatchNumber){
	$PatchNumber="488499"
	$Platform="Esb"
	$ReleaseID="R35"
	$ServerType="Admin"
	$Environment="ACORP"
}

# Variables
$ErrorActionPreference='Stop'
$PatchRoot=[String]::Format("\\balgroupit.com\appl_data\BBE\Packages\Patches\{0}\",$ReleaseID)
$PatchFolderPath=[String]::Format("{0}{1}\PR-{2}_{1}",$PatchRoot,$Platform,$PatchNumber)
$PatchXML=Join-Path $PatchFolderPath -ChildPath "$PatchNumber.xml"

Write-Host "==================================================================================="
Write-Host "PatchNumber      :"$PatchNumber
Write-Host "Platform         :"$Platform
Write-Host "Release          :"$ReleaseID
Write-Host "Patch folder path:"$PatchFolderPath
Write-Host "==================================================================================="

$xml= [xml](gc Filesystem::$PatchXML)
$Assemblies=$xml.Patch.Assembly
$PatchDeploymentActions=$xml.Patch.DeploymentActions
$ImportBinding=$PatchDeploymentActions.BindingFile
$HostInstances2Restart=$PatchDeploymentActions.hostInstancesToRestart
$StopStartApplication=$PatchDeploymentActions.StopStartApplication
$RemoveApplication=$PatchDeploymentActions.UninstallApplication
$CreateApplication=$PatchDeploymentActions.CreateApplication
$AddBiztalkReferences=$PatchDeploymentActions.AddBizTalkReferences

New-PSDrive -PSProvider FileSystem -Root $PatchFolderPath -Name 'A' -ErrorAction SilentlyContinue|Out-Null
New-PSDrive -PSProvider FileSystem -Root $global:ESBRootFolder -Name 'D' -ErrorAction SilentlyContinue|Out-Null
#New-Item $DestDIR -ItemType Directory -Force | Out-Null 
if($Assemblies){
	copy-Item "FileSystem::$($(gci Filesystem::$PatchFolderPath -Filter "ESB").FullName)" -Destination "D:\" -Force -Recurse -Verbose
}
if($ServerType -ieq "Admin"){
    # Stop BTS Application
    $ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $StopStartApplication
    if($StopStartApplication){
	    Write-Host "--- *** Stop Application *** ---"
        $StopStartLogFile=[String]::Format("{0}{1}\{2}\Deployment\{3}_StopStart.txt",$global:ESBRootFolder,$Platform,$ApplicationShortName,$PatchNumber)
        New-Item $StopStartLogFile -ItemType File -Force | Out-Null
        Stop-BTSApplication -ApplicationName $StopStartApplication | Tee-Object -FilePath $StopStartLogFile -Append 
    }

    $($global:BtsCatalogExplorer).SaveChanges()
    $($global:BtsCatalogExplorer).Refresh()
	#>
	
    # Remove BTS Application
    if($RemoveApplication){
        Write-host "--- *** Remove Application *** ---"
        $RemoveApplicationLogFile=[String]::Format("{0}{1}\{2}\Deployment\{3}_UninstallApplication.txt",$global:ESBRootFolder,$Platform,$ApplicationShortName,$PatchNumber)
        New-Item $RemoveApplicationLogFile -ItemType File -Force| Out-Null
        Remove-BTSApplication $RemoveApplication | Tee-Object -FilePath $RemoveApplicationLogFile -Append
    }

    $($global:BtsCatalogExplorer).SaveChanges()
    $($global:BtsCatalogExplorer).Refresh()

    # Create BTS Application
    if($CreateApplication){
        Write-host "--- *** Create Application *** ---"
        $CreateApplicationLogFile=[String]::Format("{0}{1}\{2}\Deployment\{3}_CreateApplication.txt",$global:ESBRootFolder,$Platform,$ApplicationShortName,$PatchNumber)
        New-Item $CreateApplicationLogFile -ItemType File -force| Out-Null
        Create-BTSApplication -ApplicationName $CreateApplication | Tee-Object -FilePath $CreateApplicationLogFile -Append
    }

    $($global:BtsCatalogExplorer).SaveChanges()
    $($global:BtsCatalogExplorer).Refresh()


    # Add BTS Application references
    if($AddBiztalkReferences){
        Write-host "--- *** Add Biztalk Application References *** ---"
        $AddBizTalkReferencesLogFile=[String]::Format("{0}{1}\{2}\Deployment\{3}_AddBizTalkReferences.txt",$global:ESBRootFolder,$Platform,$ApplicationShortName,$PatchNumber)
        New-Item $AddBizTalkReferencesLogFile -ItemType File | Out-Null
        $BizTalkReferenceApplicationRoot=$($($AddBiztalkReferences.split("="))[0])
        $BiztalkReferences=$($($AddBiztalkReferences.split("="))[1])
        ForEach($Reference in $($BiztalkReferences.split(","))){
            "Adding Reference : $Reference" | Tee-Object -FilePath $AddBizTalkReferencesLogFile -Append
             Add-References -ApplicationName $BizTalkReferenceApplicationRoot -Reference $Reference | Tee-Object -FilePath $AddBizTalkReferencesLogFile -Append
        }
    }

    $($global:BtsCatalogExplorer).SaveChanges()
    $($global:BtsCatalogExplorer).Refresh()
}

# Deploy patch folder
Write-Host "`n!!Executing deployment actions for each assemblies!!"`n

if($Assemblies){
	$Assemblies|%{
		$Assembly=$($_.Name)
		$AddToGAC=$($_.AddGac)
		$AddResource=$($_.AddResource)
		$Version=$($_.Version)
		$AssemblyPath= $(gci "A:\" -recurse -Filter "*.dll" | ?{$_.Name -ieq $Assembly}).FullName
		$AssemblyPath=$([String]$AssemblyPath.Replace($PatchFolderPath,$global:ESBRootFolder)).replace('\\','\')
		$ApplicationFolder=$AssemblyPath.Split("\")[4]
		$ApplicationDeploymentFolder = Join-Path $global:ESBRootFolder -ChildPath "Esb\$ApplicationFolder\Deployment"
		
		$BuildSequencePath="\\svw-be-bldp001\D$\ESBPatch\TFSWorkspace\Mercator.Esb.BuildSequence.xml"
		$xml=[XML](gc Filesystem::$BuildSequencePath)
		$AssemblywithoutExtension=([system.io.fileinfo]$Assembly).BaseName
		$Projects=$xml.SelectNodes("//BuildSolutions/BuildSolution/Projects/Project")
		ForEach($project in $Projects){
		$ProjectName=$project.Name
		    If($ProjectName -ilike "*$AssemblywithoutExtension.*"){ 
				$BiztalkApplicationName=$project.ParentNode.ParentNode.Name
                
                If($BiztalkApplicationName -ilike "Mercator.Esb.Framework.Services"){
                    $BiztalkApplicationName="Mercator.Esb.Framework.Services.1.0"
                }
                If($BiztalkApplicationName -ilike "Mercator.Esb.Framework"){
                    $BiztalkApplicationName="Mercator.Esb.Framework.1.0"
                }
		    }
		}
		
		Write-Host "Assembly Name    :"$Assembly
		Write-Host "Add GAC          :"$AddToGAC
		Write-Host "Add Resource     :"$AddResource
		Write-Host "Assembly Version :"$Version
		Write-Host "Application Name :"$BiztalkApplicationName
		Write-Host `n
		
		# UNGAC & GAC Assemblies
		if(Test-Path $AssemblyPath){
			if($AddToGAC -ieq "true"){
				$AddGACLogFile= [String]::Format("{0}_AddGAC.txt",$PatchNumber)
                $RemoveGACLogFile= [String]::Format("{0}_RemoveGAC.txt",$PatchNumber)
				$InstallGACLogFile=Join-Path $ApplicationDeploymentFolder -ChildPath $AddGACLogFile
                $UninstallGACLogFile=Join-Path $ApplicationDeploymentFolder -ChildPath $RemoveGACLogFile
                New-Item $UninstallGACLogFile -ItemType File -Force | Out-Null
                New-Item $InstallGACLogFile -ItemType File -Force | Out-Null
                if($AssemblyName -inotlike "Microsoft*"){
					Remove-GAC  -AssemblyName $Assembly -LogFile $UninstallGACLogFile
                }
				Write-Host "--- *** ADD GAC *** ---"
			    Add-GAC  -AssemblyPath $AssemblyPath | Add-Content -Path $InstallGACLogFile -Force
			}
			
			
			# Add-Resource
			if(($AddResource -ieq 'True') -and ($ServerType -ieq 'Admin')){
				$AddResourceLogFile=[String]::Format("{0}_AddResource.txt",$PatchNumber)
				$LogFile=Join-Path $ApplicationDeploymentFolder -ChildPath $AddResourceLogFile
				New-Item $LogFile -ItemType File -Force | Out-Null
				Write-Host "--- *** ADD RESOURCES *** ---"										
				Add-Resources -ApplicationName $BiztalkApplicationName -ResourcePath $AssemblyPath | Add-Content -Path $LogFile -Force
			}
		}
	}	
}


# Import-Bindings						
if($ImportBinding){
    #Deploy Bindings
    Write-Host "--- *** IMPORT BINDING *** ---"	
    $BiztalkApplicationName=$ImportBinding.Replace(".BindingInfo.xml","")
    $ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $BiztalkApplicationName
    $PatchSourcePath=[String]::Format("{0}{1}\ESB\PR-{2}_ESB",$global:PatchManifestRoot,$ReleaseID,$PatchNumber)
    $Filter=$Environment+'.'+$ImportBinding
	$BindingFileSourcePath=$(gci Filesystem::$PatchSourcePath -Filter "$Filter").FullName
    $BindingRoot =[String]::Format("{0}{1}\{2}\Deployment\BindingFiles\",$global:ESBRootFolder,$Platform,$ApplicationShortName)
    New-Item $BindingRoot -ItemType Directory -Force | Out-Null
    $BindingFilePath=[String]::Format("{0}{1}\{2}\Deployment\BindingFiles\{3}",$global:ESBRootFolder,$Platform,$ApplicationShortName,$ImportBinding)
    $RenameBindingFile2Old="OLD_"+$ImportBinding
    if(Test-Path $BindingFilePath){
		gci $BindingRoot | ?{$_.Name -ieq $RenameBindingFile2Old}|Remove-Item -Force -Verbose
	    gci $BindingRoot |?{$_.Name -ieq $ImportBinding} | Rename-Item -NewName $RenameBindingFile2Old
    }
    Write-Host "Binding source path:"$BindingFileSourcePath
    Write-Host "Binding root	   :"$BindingRoot
    Copy-Item $BindingFileSourcePath -Destination $BindingRoot -Force
    $Filter=$Environment+"*"
    gci $BindingRoot -Filter $Filter | Rename-Item -NewName {$_.Name -ireplace "$Environment.",""}
    $ImportBindingLogFile=[String]::Format("{0}_ImportBinding.txt",$PatchNumber)
    $BindingLogRoot=$BindingFilePath.Replace($($BindingFilePath.Split("\")[-1]),"")
	if($ServerType -ieq 'Admin'){
	    $LogFile=Join-Path $BindingLogRoot -ChildPath $ImportBindingLogFile
	    New-Item $LogFile -ItemType File -Force | Out-Null

	    Import-BindingFile -ApplicationName $BiztalkApplicationName -BindingFilePath $BindingFilePath | Add-Content -Path $LogFile -Force
	}
}
$($global:BtsCatalogExplorer).SaveChanges()
$($global:BtsCatalogExplorer).Refresh()

if($ServerType -ieq 'Admin'){
    # Stop&Start host instances
    if($HostInstances2Restart){
	    Write-Host `n
	    Write-Host "--- *** Restarting host instances *** ----"
	    ForEach($hostInstance in $HostInstances2Restart.Split(",")){
		    $hostInstances=Get-WmiObject MSBTS_HostInstance -namespace root\MicrosoftBizTalkServer -ErrorAction Stop
		    ForEach($instance in $hostInstances){
			    If($($instance.HostName) -ieq $hostInstance){
				    Write-Host "Stopping host instance:"$hostInstance
				    $instance.Stop() | Out-Null
				    If($LASTEXITCODE -ieq '0'){
					    Write-Host "Stopped host instance:"$hostInstance `n
				    }
				    Write-Host "Starting host instance:"$hostInstance
				    $instance.Start()|Out-Null
				    If($LASTEXITCODE -ieq '0'){
					    Write-Host "Started host instance:"$hostInstance `n
				    }
			    }
		    }
	    }
    }

    # Start BTS Application
    if($StopStartApplication){
	    Write-Host "--- *** Start Application *** ---"
        Start-BTSApplication -ApplicationName $StopStartApplication | Tee-Object -FilePath $StopStartLogFile -Append 
    }
}#>
Remove-PSDrive -Name 'D' -ErrorAction SilentlyContinue -Force |Out-Null
Remove-PSDrive -Name 'A' -ErrorAction SilentlyContinue -Force |Out-Null