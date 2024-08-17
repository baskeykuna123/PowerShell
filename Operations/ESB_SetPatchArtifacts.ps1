param($MercatorBuildVersion,$Release)


if(!$MercatorBuildVersion){
	$Release="R31"
	$MercatorBuildVersion="4.27"
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


$patchmanifest=$global:PatchManifest
$BuildSequnceXML="\\SHW-ME-PDNET01\nolio\TFSWorkspace\Mercator.Esb.BuildSequence.xml"

$BuidlServerName="svw-be-bldp001"
$Application="ESB"
$Patchxml=[XML](Get-Content FileSystem::$patchmanifest)
$xml=[XML](Get-Content FileSystem::$BuildSequnceXML)
$patches=$Patchxml.SelectNodes("//Release/Application[@Name='$Application']/PatchRequest")

foreach($patch in $patches){
	if($patch.State -ilike "*Planned")
	{
		$env=($patch.State -split " ")[0]
		$patchSource=[string]::Format("{0}{1}\{2}\PR-{3}_ESB\",[System.Web.HttpUtility]::HtmlDecode($patch.ParentNode.ParentNode.source),$Release,$env,$patch.number)
		Write-host "Patch Number : " $patch.Number
		Write-host "Patch State  : " $patch.State
		Write-host "Patch Source : " $patchSource
		Write-host "***********************Assemblies********************************************"
		foreach($Assembly in $($patch.Assembly)){
			$AssemblyNameWithoutEx = [system.io.Path]::GetFileNameWithoutExtension($Assembly.Name)
			$xmlnodes = $xml.SelectNodes("//BuildSolution/Projects/Project")
			
			foreach($node in $xmlnodes){
				if(($node.Name) -ilike "$AssemblyNameWithoutEx*"){
					$AssemblyNameWithoutEx
					$xmlnode=$node.ParentNode.ParentNode
					$rootver=$xmlnode.RootPath.ActiveVersions.Version
					$slnfolder=$xmlnode.Name | % { $_.replace("Baloise.Esb.Service","BEService")} | % { $_.replace("Mercator.Esb.","")} | % { $_.replace("Baloise.Esb.","")} | % { $_.replace(".","")}
					$subfolder=$AssemblyNameWithoutEx | % { $_.replace("Baloise.Esb.Service","BEService")} | % { $_.replace("Mercator.Esb.","")} | % { $_.replace("Baloise.Esb.","")} 
					
					$ver=$Assembly.ver
					if($ver-eq "" ){
						if($node.ActiveVersions.Childnodes.Count > 1){
							Write-Error "Multiple Versions found for $($Assembly.Name) please specify proper version in the global Manifest at $global:PatchManifest"
							exit 1
						}
						else{
							$ver=$node.ActiveVersions.Version
						}
					}
				}
			}
			
			# Check for His project and assemblies
			$ApplicationName=$($xml.BuildSolutions.BuildSolution|?{ $($_.Projects.Project.GeneratedAssemblies.Assembly) -ieq $($Assembly.Name)}).Name
			$HisAssemblyProject=$($xml.SelectNodes("//BuildSolution[@name='$ApplicationName']/Projects/Project")|?{$($_.GeneratedAssemblies.Assembly) -ieq $($Assembly.Name)}).Name
			If($HisAssemblyProject){
				$HisAssemblyProject=$HisAssemblyProject |%{$_.replace("Baloise.Esb.Service","BEService")} | % { $_.replace("Mercator.Esb.","")}|% { $_.replace("Baloise.Esb.","")} 
				$subfolder=[system.io.Path]::GetFileNameWithoutExtension($HisAssemblyProject)
				$ver=$Assembly.ver
				if($ver-eq "" ){
					if($node.ActiveVersions.Childnodes.Count > 1){
						Write-Error "Multiple Versions found for $($Assembly.Name) please specify proper version in the global Manifest at $global:PatchManifest"
						exit 1
					}
					else{
						$ver=$node.ActiveVersions.Version
					}
				}
			}
			
			if($slnfolder -ieq "Framework"){
				$subfolder=""
			}
			
			$AssemblyBuildPath=([string]::Format("\\{0}\{1}_CUSTOM_{2}_LATEST\{3}\{4}\{5}",$BuidlServerName,$MercatorBuildVersion,$slnfolder,$rootver,$subfolder,$ver))
			$AssemblyBuildPath
			
			$AssemblyBuildPath="\" + $AssemblyBuildPath -replace [regex]::escape("\\"),"\"
			Write-Host "Assembly build path:"$AssemblyBuildPath
			$dllpath=(Get-ChildItem -Path FileSystem::"$($AssemblyBuildPath)" -Filter $($Assembly.Name) -Recurse ).FullName
			Write-Host "Assembly name:" $($Assembly.Name)
			Write-Host "DLL Path:"$dllpath
			$filedate=(Get-ChildItem Filesystem::$dllpath).CreationTime
			$now = get-date
			if($filedate -le $now.AddHours(-1)){
				Write-Host  'latest build assembly unavailable for patch. please verify patch build'
				Write-Host "$($Assembly.Name) : $filedate"
				Exit 1
			}
			Write-Host  "$($Assembly.Name) : $filedate"
			copy-item -Path filesystem::$dllpath -Destination filesystem::$patchSource -Force -Verbose
		}
	}
}
