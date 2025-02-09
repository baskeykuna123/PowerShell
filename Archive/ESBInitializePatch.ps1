PARAM($Release,$PatchNumber,$ApplicationVersion)

#Default environment and Application names
if(!$Release){
	$Release = "R36"
    $PatchNumber="497227"
	$ApplicationVersion="35.24.12.20"
}
clear

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$ErrorActionPreference="Stop"
$Application = "ESB"
$patchmanifest=[String]::Format("{0}{1}\{2}\PR-{3}_{2}\{3}.xml",$global:PatchManifestRoot,$Release,$Application,$patchNumber)
$Patchxml = [xml](Get-Content Filesystem::$patchmanifest)
$patch = $Patchxml.SelectNodes("//Patch")
$DeployXML = "\\svw-be-bldp001\D$\ESBPatch\TFSWorkspace\Mercator.Esb.BuildSequence.xml"
$xml = [xml](Get-Content filesystem::$DeployXML)
$BindingFile=$patch.DeploymentActions.BindingFile

If($($Patch.state) -ilike "*Planned*"){
	$env = ($patch.State -split " ")[0]
	$PatchSourcePath=[String]::Format("{0}{1}\{2}\PR-{3}_{2}",$global:PatchManifestRoot,$Release,$Application,$patch.number)
	Write-Host "Patch source:" $PatchSourcePath
	New-PSDrive -Name "B" -PSProvider "FileSystem" -Root "$PatchSourcePath" -ErrorAction SilentlyContinue | Out-Null
	Write-Host "`nPatch Number : " $patch.number
	Write-Host "==========================$($patch.number)================================================="
	
	foreach ($Assembly in $patch.Assembly){
		$fileName = [System.io.Path]::GetFileNameWithoutExtension($Assembly.Name)
  		$xmlnodes = $xml.SelectNodes("//BuildSolution/Projects/Project")
  		
		foreach ($node in $xmlnodes) {
    		if (($node.Name) -match $fileName) {
      			$xmlnode = $node.ParentNode.ParentNode
				$rootver = $xmlnode.RootPath.ActiveVersions.Version
				$slnfolder = $xmlnode.Name -replace "Mercator.Esb.",""
				$slnfolder = $slnfolder -replace "Baloise.Esb.",""
				$slnfolder = $slnfolder -replace [regex]::escape('.'),''
				$subfolder = $AssemblyName -replace "Mercator.Esb.",""
				$subfolder = $subfolder -replace "Baloise.Esb",""
    		}
  		}
  		$appname = $xmlnode.Name
  		Write-Host "-----------------Assemblies-----------------------------------"
  		Write-Host "Assembly Name    : " $Assembly.Name
  		Write-Host "Application Name : " $appname
  		Write-Host "Assembly Version : " $Assembly.Version
	    $fileinfo = "*" + $Assembly.version + "*" + $Assembly.Name
  		$assemblypath = Get-ChildItem -Path '\\svw-be-bizi001\E$\program files\Mercator\ESB\' -Filter *.dll -Recurse | Where-Object { $_.FullName -like $fileinfo } | ForEach-Object { $_.FullName }
  		Write-Host "--" $assemblypath
  		if(!$assemblypath){
  			Write-Host "Assembly not found.... "
			EXIT 1
  		}
		$appfolder = $appname -replace "Mercator.Esb.",""
		$appfolder = $appfolder -replace "Baloise.Esb.","BE"	  
		$serpath = $assemblypath.Replace("\\svw-be-bizi001\E$\program files\Mercator","")
		$serpath=Split-Path -Parent $serpath
		$finalpath = join-path B: -ChildPath $serpath
		New-Item -ItemType Directory -Force -Path $finalpath | Out-Null
        $filename = join-path B: -ChildPath $($Assembly.Name)
        Write-Host "File name :"$filename
        Write-Host "Final path:"$finalpath
		Move-Item $filename -Destination $finalpath -Force -Verbose
	}
	Write-Host "-----------------Assemblies-----------------------------------"
	Remove-PSDrive -Name "B" -ErrorAction SilentlyContinue | Out-Null
}

# Place IAP binding files in patch folder.
$BindingFile=$patch.DeploymentActions.BindingFile
	If($BindingFile){
	$ApplicationName =$BindingFile.Replace(".BindingInfo.xml","")
	$ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $ApplicationName
	$BindingPackageRoot=[String]::Format("{0}\ESB\{1}\{2}\Deployment\BindingFiles",$global:NewPackageRoot,$ApplicationVersion,$ApplicationShortName)
	gci Filesystem::$BindingPackageRoot -Filter "*corp*"|%{
		copy-Item $_.FullName -Destination "$PatchSourcePath\" -Force
	}
}