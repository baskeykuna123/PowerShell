param($PatchNumber,$Release)
if(!$PatchNumber){
	$PatchNumber="485869"
	$Release="R35"
}
$ErrorActionPreference="Stop"
clear
Add-Type -AssemblyName System.Web

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

# Variables
$patchinfo=get-childitem  Filesystem::$global:PatchManifestRoot -filter "*$($PatchNumber).xml*" -Force -Recurse
$Patchxmlfile=$patchinfo.FullName
$Patchfolder=$patchinfo.DirectoryName
$currentdate=Get-Date -Format "yyyyMMdd"
$Patchxml=[XML](Get-Content FileSystem::$Patchxmlfile)
$MNETBaserVersion=$Patchxml.Patch.ApplicationBaseVersion
$latestbuildfoldefilter=[string]::Format("LR_*_{0}_*",$currentdate)
$buildfolder=Get-ChildItem filesystem::"\\SHW-ME-PDTALK51\f$\B_$($MNETBaserVersion)" -Filter "$latestbuildfoldefilter" -Force |sort -desc |Select -first 1

$buildoutputfolder=Join-Path $buildfolder.FullName -ChildPath "buildoutput"
$assemblies=$Patchxml.SelectNodes("//Patch/Assembly")

Remove-PSDrive -Name "U" -ErrorAction SilentlyContinue
New-PSDrive -Name "U" -PSProvider "FileSystem" -Root "$Patchfolder" |Out-Null

# Server Folders
$FrontserverFolder="\\IWEBFM01\E$\Mercator\"
$BackServerFolder="\\ISERVFM01\E$\Program Files\"
$DOCServiceFolder="\\svw-be-eaii01\E$\Program Files\"


# //BACK  - Gac & UnGac
$BackserverFolderGacBatFile="\\iservfm01\E$\Program Files\Mercator\Deployment\MERCATORSERVICES_gac.bat"
$BackOfficePatchGacbatFile=[String]::Format("{0}\Back_AddGac.bat",$patchfolder)
$BackserverFolderUNGacBatFile="\\iservfm01\E$\Program Files\Mercator\Deployment\MERCATORSERVICES_ungac.bat"
$BackOfficePatchUNGacbatFile=[String]::Format("{0}\Back_UnGac.bat",$patchfolder)

# //FRONT  - Gac & UnGac
$FrontserverFolderGacBatFile="\\iwebfm01\E$\Mercator\Deployment\MERCATORWEBFARM_gac.bat"
$FrontOfficePatchGacbatFile=[String]::Format("{0}\Front_AddGac.bat",$patchfolder)
$FrontserverFolderUNGacBatFile="\\iwebfm01\E$\Mercator\Deployment\MERCATORWEBFARM_ungac.bat"
$FrontOfficePatchUNGacbatFile=[String]::Format("{0}\Front_UnGac.bat",$patchfolder)

# //DOC-SERVICE  - Gac & UnGac
$DOCServiceFolderGacBatFile="\\svw-be-eaii01\E$\Program Files\Mercator\Eai\InstallationUtilities\EAIDOCSRV_gac.bat"
$DOCServicePatchGacbatFile=[String]::Format("{0}\DOCService_AddGac.bat",$patchfolder)
$DOCServiceFolderUNGacBatFile="\\svw-be-eaii01\E$\Program Files\Mercator\Eai\InstallationUtilities\EAIDOCSRV_ungac.bat"
$DOCServicePatchUNGacbatFile=[String]::Format("{0}\DOCService_UnGac.bat",$patchfolder)

#Retrieving Assemblies from the build folders
foreach($Assembly in $assemblies){
	Write-Host "======================================================================================"
	Write-Host "Getting Assembly : " $Assembly.Name
	$AssemblyName=$Assembly.Name
	$AssemblyNameWithoutEx = [system.io.Path]::GetFileNameWithoutExtension($Assembly.Name)
	$version=$Assembly.Version
	$assemblypath=Get-ChildItem Filesystem::$buildoutputfolder -Filter $AssemblyName -Force -Recurse | select -First 1
	$assemblypath
	if($assemblypath.LastWriteTime -le (get-date).AddHours(-2)){
		Write-Host  'ERROR : latest build assembly unavailable for patch. please verify patch build'
		Write-Host " Assembly Found =>$AssemblyName | CreatedDatetime - $($assemblypath.LastWriteTime)"
		Exit 1
	}
	
	Write-Host  " Assembly Found => $AssemblyName | CreatedDatetime - $($assemblypath.LastWriteTime)"
	copy-item -Path filesystem::$($assemblypath.FullName) -Destination "U:\" -Force					
	Write-Host "======================================================================================"

	#searching the deployment folder of the assemblies and preparing the deployment structure
	#The search will be done on the ICORP FRONT and BACK office servers
	$AssemblyNode=$Patchxml.SelectNodes("//Patch/Assembly[@Name='$($Assembly.Name)']")
	$FlagtoGacFrontAssemblies=$AssemblyNode.AddGac2Front
	$FlagtoGacBackAssemblies=$AssemblyNode.AddGac2Back
	$FlagtoGacDocServiceAssemblies=$AssemblyNode.AddGac2Back
	$dll=$($Assembly.Name)
	$Frontfolders=(Get-ChildItem filesystem::$FrontserverFolder -Force -Recurse -Filter $dll).DirectoryName
	If($Frontfolders){
		foreach($folder in $Frontfolders){	
			$folder=$folder.replace($FrontserverFolder,"U:\FrontOffice\")
			new-item -ItemType directory -Path $folder -Force |Out-Null
			Copy-Item "U:\$AssemblyName" -Destination $folder		
			$GetMatchedString2GacFront=gc Filesystem::$FrontserverFolderGacBatFile | Select-String -Pattern "$dll" | Select -Unique -ErrorAction Stop
			$GetMatchedString2UnGacFront=gc Filesystem::$FrontserverFolderUNGacBatFile | Select-String -Pattern "$dll" | Select -Unique -ErrorAction Stop
			If(($GetMatchedString2GacFront) -and ($GetMatchedString2UnGacFront)){
				If(((-not $FlagtoGacFrontAssemblies)) -and ($folder -ilike "*Shared*")){
					$AssemblyNode.SetAttribute("AddGac2Front","true")
				}	
				New-Item Filesystem::$FrontOfficePatchGacbatFile -ItemType File -Force | Out-Null
				New-Item Filesystem::$FrontOfficePatchUNGacbatFile -ItemType File -Force | Out-Null
		
				Add-Content Filesystem::$FrontOfficePatchGacbatFile -Value $GetMatchedString2GacFront -Force -Verbose
				Add-Content Filesystem::$FrontOfficePatchUNGacbatFile -Value $GetMatchedString2UnGacFront -Force -Verbose
			}

		}
	}
	$Backfolders=(Get-ChildItem filesystem::$BackServerFolder -Force -Recurse -Filter $dll).DirectoryName
	If($Backfolders){
		foreach($folder in $Backfolders){	
			$folder=$folder.replace($BackserverFolder,"U:\BackOffice\")
			new-item -ItemType directory -Path $folder -Force |Out-Null
			Copy-Item "U:\$AssemblyName" -Destination $folder		
			$GetMatchedString2GacBack=gc Filesystem::$BackserverFolderGacBatFile | Select-String -Pattern "$dll" | Select -Unique -ErrorAction Stop
			$GetMatchedString2UngacBack=gc Filesystem::$BackserverFolderUNGacBatFile | Select-String -Pattern "$dll" | Select -Unique -ErrorAction Stop
			If(($GetMatchedString2GacBack) -and ($GetMatchedString2UngacBack)){
				If(((-not $FlagtoGacBackAssemblies)) -and ($folder -ilike "*Shared*")){
					$AssemblyNode.SetAttribute("AddGac2Back","true")
				}
				New-Item Filesystem::$BackOfficePatchGacbatFile -ItemType File -Force | Out-Null
				New-Item Filesystem::$BackOfficePatchUNGacbatFile -ItemType File -Force | Out-Null
				
				Add-Content Filesystem::$BackOfficePatchGacbatFile -Value $GetMatchedString2GacBack -Force -Verbose
				Add-Content Filesystem::$BackOfficePatchUNGacbatFile -Value $GetMatchedString2UngacBack -Force -Verbose
			}
		}
	}
	$DocServicefolders=(Get-ChildItem filesystem::$DOCServiceFolder -Force -Recurse -Filter $dll).DirectoryName
	If($DocServicefolders){
		foreach($folder in $DocServicefolders){	
			$folder=$folder.replace($DOCServiceFolder,"U:\DocService\")
			new-item -ItemType directory -Path $folder -Force |Out-Null
			Copy-Item "U:\$AssemblyName" -Destination $folder	
			$GetMatchedString2GacDOCService=gc Filesystem::$DOCServiceFolderGacBatFile | Select-String -Pattern "$dll" | Select -Unique -ErrorAction Stop
			$GetMatchedString2UnGacDOCService=gc Filesystem::$DOCServiceFolderUNGacBatFile | Select-String -Pattern "$dll" | Select -Unique -ErrorAction Stop
			If(($GetMatchedString2GacDOCService) -and ($GetMatchedString2UnGacDOCService)){
				If(-not ($FlagtoGacDocServiceAssemblies)){
					$AssemblyNode.SetAttribute("AddGac2DOCService","true")
				}
				New-Item Filesystem::$DOCServicePatchGacbatFile -ItemType File -Force | Out-Null
				New-Item Filesystem::$DOCServicePatchUNGacbatFile -ItemType File -Force | Out-Null
				
				Add-Content Filesystem::$DOCServicePatchGacbatFile -Value $GetMatchedString2GacDOCService -Force -Verbose 
				Add-Content Filesystem::$DOCServicePatchUNGacbatFile -Value $GetMatchedString2UnGacDOCService -Force -Verbose
			}
		}
	}
	$Patchxml.Save($Patchxmlfile)
}
Remove-PSDrive -Name "U" -ErrorAction SilentlyContinue