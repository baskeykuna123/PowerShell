param($patchNumber,$ServerType,$ReleaseID)
CLS

if(!$patchNumber){
	$patchNumber='393633'
	$ServerType="Front"
	$ReleaseID="R31"
}

# loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

# Variables
$PatchRoot=Join-Path $global:NewPackageRoot -ChildPath "Patches\$ReleaseID"
$PatchFolder=gci FileSystem::$PatchRoot -Recurse -Directory -Filter "*$patchNumber*" 

$appName=$($PatchFolder.Name).Split("_")[1]
$PatchSource=[String]::Format("{0}\{1}\{2}",$PatchRoot,$appName,$PatchFolder)
$SOSSBatFile=[String]::Format("{0}\ClearSOSS.bat",$PatchSource)

if(Test-Path Filesystem::$PatchSource){
	switch($ServerType){
		"Front" {
			$Folder2deploy="FrontOffice"
			$DeploymentFolder="E:\Mercator"
			$ManagementFolder=Join-Path $DeploymentFolder -ChildPath "Management"
			$RecycleAppPoolBatFile=Join-Path $ManagementFolder -ChildPath "WEBFMServer_Recycle.bat"
            $SOSSBatFile=Join-Path $ManagementFolder -ChildPath "WEBFMServer_ClearSOSS.bat"
		}
		"Back" {
			$Folder2deploy="BackOffice"
			$DeploymentFolder="E:\Program Files"
			$ManagementFolder=Join-Path $DeploymentFolder -ChildPath "Mercator\Management"
			$StopServiceBatFile=Join-Path $ManagementFolder -ChildPath "ServicesServer_Stop.bat"
			$StartServiceBatFile=Join-Path $ManagementFolder -ChildPath "ServicesServer_Start.bat"
            $SOSSBatFile=Join-Path $ManagementFolder -ChildPath "ServicesServer_ClearSOSS"		
		}
		"DocService" {
			$Folder2deploy="DocService"
			$DeploymentFolder="E:\Program Files"
			$ManagementFolder=Join-Path $DeploymentFolder -ChildPath "Mercator\Eai\InstallationUtilities"
			$StopServiceBatFile=Join-Path $ManagementFolder -ChildPath "EAIDOCSERVICE_Stop.bat"
			$StartServiceBatFile=Join-Path $ManagementFolder -ChildPath "EAIDOCSERVICE_Start.bat"
            $SOSSBatFile=Join-Path $ManagementFolder -ChildPath "EAI_ClearSOSS.bat"
		}
	}	
}

# Display Variables
Write-Host "=================================================="
Write-Host "| Patch number:"$patchNumber
Write-Host "| Patch source:"$PatchSource
Write-Host "| Release ID  :"$ReleaseID
Write-Host "| ServerType  :"$ServerType
Write-Host "| Platform    :"$appName
Write-Host "==================================================="


# copy patch folders to the server
$DeployableFolderPath=[String]::Format("{0}\{1}",$PatchSource,$Folder2deploy)
Copy-Item "Filesystem::$DeployableFolderPath\*" -Destination "$DeploymentFolder\" -Force -recurse -Verbose -ErrorAction Stop


$GacBatFile=[String]::Format("{0}\{1}_AddGac.bat",$PatchSource,$ServerType)
$UnGacBatFile=[String]::Format("{0}\{1}_UnGac.bat",$PatchSource,$ServerType)
$TempFolder=[String]::Format("C:\TEMP\{0}",$patchNumber)
New-Item -ItemType Directory $TempFolder -Force | Out-Null
Copy-Item $UnGacBatFile -Destination $TempFolder -Force
Copy-Item $GacBatFile -Destination $TempFolder -Force
$GACBat=Join-Path $TempFolder -childPath "$($ServerType)_AddGac.bat"
$UNGacBat=Join-Path $TempFolder -childPath "$($ServerType)_UnGac.bat"

# Reading XMLs to GAC assemblies
$ReadPatchXML=[XML](gc Filesystem::$($(gci filesystem::$PatchSource -Filter "*$patchNumber.xml*").FullName))

$AddGAC='AddGac2'+$ServerType
$ReadPatchXML.Patch|%{
	$_.Assembly|%{
		If($($_.$AddGAC) -ieq "true"){
            Write-Host `n
            Write-Host "INFO: GACING.."
			Start-Process -FilePath $UNGacBat -Verb RunAs -Wait -ErrorAction Stop
			Start-Process -FilePath $GACBat -Verb RunAs -Wait -ErrorAction Stop
			Write-Host "GACED: $($_.Name)"
		}
	}
	if($($_.DeploymentActions.ClearSoss) -ieq 'true'){
        Write-Host `n
        Write-Host "INFO: Clearing SOSS.."
		Start-Process -FilePath $SOSSBatFile -Verb RunAs -Wait -ErrorAction Stop
        Write-Host "INFO : SOSS Cleared."
	}
	if($($_.DeploymentActions.StartStop) -ieq 'true'){
		If($ServerType -ieq "Front"){
            Write-Host `n
            Write-Host "INFO: Recycling application pools"
			Start-Process -FilePath $RecycleAppPoolBatFile -Verb RunAs -Wait -ErrorAction Stop
            Write-Host "INFO: Apppool recycled."
		}
		Else{
            Write-Host `n
            Write-Host "INFO: Restarting Services.."
            Write-Host "INFO: Stopping Services.."
			Start-Process -FilePath $StopServiceBatFile -Verb RunAs -Wait -ErrorAction Stop
            Write-Host "INFO: Services Stopped"
            Write-Host "INFO: Starting Services.."
			Start-Process -FilePath $StartServiceBatFile -Verb RunAs -Wait -ErrorAction Stop
            Write-Host "INFO: Services started."
		}
	}
}
#Deleting temp pat ch folder 
Remove-Item $TempFolder -Force -Recurse
