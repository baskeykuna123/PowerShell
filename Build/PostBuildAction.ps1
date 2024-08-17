# Enable -Verbose option
[CmdletBinding()]

param([String]$TfsSourceFolder,[String]$TfsStagingFolder,[String]$BuildID)

if (! $TfsSourceFolder){
    $TfsSourceFolder = "E:\TFSBuild\4\s"
    $TfsStagingFolder = "E:\TFSBuild\4\a"
    $BuildID="DEV_CentralDataStore_20190807.1"
    $VerbosePreference = "Continue"
    #$VerbosePreference = "SilentlyContinue"
}

Write-Host "TfsSourceFolder= $TfsSourceFolder"
Write-Host "TfsStagingFolder= $TfsStagingFolder"
Write-Host "BuildID= $BuildID"

Write-Host "looking for AfterBuildActions.xml"
$BuildVersion = $BuildID.Split("_")[$BuildID.Split("_").Length - 1]
$BuildDefenitionname = $BuildID.Replace("_" + $BuildVersion , "")
$applicationName = $BuildDefenitionname.Split("_")[$BuildDefenitionname.Split("_").Length - 1]
$afterBuildActionsFileName = [String]::Format("{0}{1}",$applicationName,"AfterBuildActions.xml")

$afterBuildActionsFile = Get-ChildItem -Path $TfsSourceFolder -Filter $afterBuildActionsFileName -Recurse -ErrorAction SilentlyContinue
if ($afterBuildActionsFile){
	$afterBuildActionsXml = [xml] (Get-Content -Path $afterBuildActionsFile.FullName)
	$afterBuildActionsXml.SelectNodes("AfterBuildActions").ChildNodes  | where {$_.NodeType -ne "Comment"} | foreach {
		$currentAction = $_
		switch ($currentAction.Name){
			 "CopyBuildOutputFolder" {
				$sourceProject = $currentAction.Attributes.GetNamedItem("sourceProject").Value
				$destinationProject = $currentAction.Attributes.GetNamedItem("destinationProject").Value
				$SourceBuildoutputfolder=$currentAction.Attributes.GetNamedItem("SourceBuildoutputfolder").Value
				$DestinationBuildoutputfolder=$currentAction.Attributes.GetNamedItem("DestinationBuildoutputfolder").Value
				$overwrite=$currentAction.Attributes.GetNamedItem("overWriteFilesInDestination").Value
                if ($overwrite){
                    $overwrite=[System.Convert]::ToBoolean($overwrite)
                }
                else{
                    $overwrite=$true
                }
				#find sourceProject in TfsSourceFolder
				$sourceprojectFile = Get-ChildItem -Path $TfsSourceFolder -Include $sourceProject -Recurse
				if ( ! (Test-Path $sourceprojectFile)){
					Write-Error "$($sourceProject) not recursively found in $($TfsSourceFolder)"
					exit 1
				}
				#find sourceProjectSubPath under sourceProject folder
				 $SourceFolder=(Get-ChildItem $($sourceprojectFile.DirectoryName) -filter $SourceBuildoutputfolder -Force -Recurse).FullName
			
				if ( (! $SourceFolder ) -or (! (Test-Path $sourceFolder))){
					Write-Error "$($sourceProjectSubPath) not found in $($sourceprojectFile.DirectoryName)"
					exit 1
				}
				else{
					Write-Verbose "source folder found at $($sourceFolder)"
				}

				$destinationProjectFile = Get-ChildItem -Path $TfsSourceFolder -Include $destinationProject -Recurse
				if ( ! (Test-Path $destinationProjectFile)){
					Write-Error "$($destinationProject) not recursively found in $($TfsSourceFolder)"
					exit 1
				}
				#find sourceProjectSubPath under sourceProject folder
				 $DestinationFolder=(Get-ChildItem $($destinationProjectFile.DirectoryName) -filter $DestinationBuildoutputfolder -Force -Recurse).FullName
			
				if ( ! (Test-Path $DestinationFolder)){
					Write-Error "$($DestinationBuildoutputfolder) not found in $($destinationProjectFile.DirectoryName)"
					exit 1
				}
				else{
					Write-Verbose "Destination folder found at $($DestinationFolder)"
				}
			
                if($overwrite){
    		        $copiedItems = Copy-Item "$sourceFolder\*" -Destination $DestinationFolder -Filter "$includeFiles" -Recurse -Force -PassThru
			        Write-Verbose "$($copiedItems.Count) items copied."
                }
                else{
                    $SourceFiles = Get-ChildItem -Path $SourceFolder -Recurse #| where { ! $_.PSIsContainer }
                    $currentLocation=Get-Location

                    foreach ($file in $SourceFiles) 
                    {
                        $src = $file.FullName
                        if ($file.DirectoryName -ieq $SourceFolder){
                            $dest = Join-Path -Path $DestinationFolder -ChildPath $file.Name
                        }
                        else{
                            Set-Location $SourceFolder
                            $relativePath = $file | Resolve-Path -Relative
                            $dest = Join-Path -Path $DestinationFolder -ChildPath $relativePath # | Join-Path -ChildPath $file.Name
                        }

                        if (!(Test-Path $dest))    {
                            Copy-Item $src -Destination $dest -PassThru -Force
                        }
                    }
                    Set-Location $currentLocation
                }
            }
			"copyProjectFolders" {
				$sourceProject = $currentAction.Attributes.GetNamedItem("sourceProject").Value
				$sourceProjectSubPath = $currentAction.Attributes.GetNamedItem("sourceProjectSubPath").Value
				$destinationProject = $currentAction.Attributes.GetNamedItem("destinationProject").Value
				$destinationProjectSubPath = $currentAction.Attributes.GetNamedItem("destinationProjectSubPath").Value
				$includeFiles = $currentAction.Attributes.GetNamedItem("include").Value
				$recursive = $currentAction.Attributes.GetNamedItem("recursive").Value
			
				#find sourceProject in TfsSourceFolder
				$sourceprojectFile = Get-ChildItem -Path $TfsSourceFolder -Include $sourceProject -Recurse
				if ( ! (Test-Path $sourceprojectFile)){
					Write-Error "$($sourceProject) not recursively found in $($TfsSourceFolder)"
					exit 1
				}
				#find sourceProjectSubPath under sourceProject folder
				$sourceFolder = Join-Path -Path $sourceprojectFile.DirectoryName -ChildPath $sourceProjectSubPath
				if ( ! (Test-Path $sourceFolder)){
					Write-Error "$($sourceProjectSubPath) not found in $($sourceprojectFile.DirectoryName)"
					exit 1
				}
				else{
					Write-Verbose "source folder found at $($sourceFolder)"
				}
			
				#find destinationProjectFolders in TfsStagingFolder
				$Extention = $destinationProject.Split(".")[$destinationProject.Split(".").Length - 1]
				$destinationProjectNoExt = $destinationProject -replace (".$Extention", "")
				$destinationprojectFolders = Get-ChildItem -Path $TfsStagingFolder -Include $destinationProjectNoExt -Recurse
			
				#Select the path with the deepest depth
				$deepestDepth = 0
				$destinationprojectFolders | Foreach { 
					$currentDepth = $_.FullName.Split("\\").count
					if ($currentDepth -gt $deepestDepth){
						$deepestDepth = $currentDepth
						$deepestPath = $_.FullName
					}
				}

				if ( ! (Test-Path $deepestPath)){
					Write-Error "$($deepestPath) not recursively found in $($TfsStagingFolder)"
					exit 1
				}
			
				$destinationPath = Join-Path -Path $deepestPath -ChildPath $destinationProjectSubPath
				Write-Verbose "Destination folder found at $($destinationPath)"
			
				$copiedItems = Copy-Item $sourceFolder -Destination $destinationPath -Filter $includeFiles -Recurse -Force -PassThru
				Write-Verbose "$($copiedItems.Count) items copied.."
			}
		
			"copyProjectFiles" {
				$sourceProject = $currentAction.Attributes.GetNamedItem("sourceProject").Value
				$includeFiles = $currentAction.Attributes.GetNamedItem("includeFiles").Value
				$destinationProject = $currentAction.Attributes.GetNamedItem("destinationProject").Value
				$destinationProjectSubPath = $currentAction.Attributes.GetNamedItem("destinationProjectSubPath").Value
			
				#find sourceProject in TfsSourceFolder
				$sourceprojectFile = Get-ChildItem -Path $TfsSourceFolder -Include $sourceProject -Recurse
				if ( ! (Test-Path $sourceprojectFile)){
					Write-Error "$($includeFiles) not recursively found in $($TfsSourceFolder)"
					exit 1
				}
			
				#find destinationProjectFolders in TfsStagingFolder
				$Extention = $destinationProject.Split(".")[$destinationProject.Split(".").Length - 1]
				$destinationProjectNoExt = $destinationProject -replace (".$Extention", "")
				$destinationprojectFolders = Get-ChildItem -Path $TfsStagingFolder -Include $destinationProjectNoExt -Recurse
			
				#Select the path with the deepest depth
				$deepestDepth = 0
				$destinationprojectFolders | Foreach { 
					$currentDepth = $_.FullName.Split("\\").count
					if ($currentDepth -gt $deepestDepth){
						$deepestDepth = $currentDepth
						$deepestPath = $_.FullName
					}
				}

				if ( ! (Test-Path $deepestPath)){
					Write-Error "$($deepestPath) not recursively found in $($TfsStagingFolder)"
					exit 1
				}
			
				$destinationPath = Join-Path -Path $deepestPath -ChildPath $destinationProjectSubPath
				Write-Verbose "Destination folder found at $($destinationPath)"
			
				$includeFiles.Split(",") | foreach {			
					Get-ChildItem $sourceprojectFile.DirectoryName -File $_ -Recurse | foreach {				
						$copiedItems = Copy-Item $_.FullName -Destination $destinationPath  -Force -PassThru
						Write-Verbose "$($copiedItems.Count) items copied : $($copiedItems.Name)"
					}
				}
			}


			"copyReferencedAssembly" {
				$includeFiles = $currentAction.Attributes.GetNamedItem("includeFiles").Value
				$destinationProject = $currentAction.Attributes.GetNamedItem("destinationProject").Value
				$destinationProjectSubPath = $currentAction.Attributes.GetNamedItem("destinationProjectSubPath").Value
			
				#find destinationProjectFolders in TfsStagingFolder
				$Extention = $destinationProject.Split(".")[$destinationProject.Split(".").Length - 1]
				$destinationProjectNoExt = $destinationProject -replace (".$Extention", "")
				$destinationprojectFolders = Get-ChildItem -Path $TfsStagingFolder -Include $destinationProjectNoExt -Recurse
			
				#Select the path with the deepest depth
				$deepestDepth = 0
				$destinationprojectFolders | Foreach { 
					$currentDepth = $_.FullName.Split("\\").count
					if ($currentDepth -gt $deepestDepth){
						$deepestDepth = $currentDepth
						$deepestPath = $_.FullName
					}
				}

				if ( ! (Test-Path $deepestPath)){
					Write-Error "$($deepestPath) not recursively found in $($TfsStagingFolder)"
					exit 1
				}
			
				$destinationPath = Join-Path -Path $deepestPath -ChildPath $destinationProjectSubPath
				Write-Verbose "Destination folder found at $($destinationPath)"
			
				$includeFiles.Split(",") | foreach {			
					Get-ChildItem $TfsSourceFolder -File $_ -Recurse | foreach {				
						$copiedItems = Copy-Item $_.FullName -Destination $destinationPath  -Force -PassThru
						Write-Verbose "$($copiedItems.Count) items copied : $($copiedItems.Name)"
					}
				}
			}
		
			default {
				Write-Verbose "Action $($currentAction.Name) is not (yet) implemented."
			}
		}
	}

}
else{
    write-host "$afterBuildActionsFileName not found."
}


Write-Host "looking for DeploymentManifest.xml"
$deploymentManifestFileName = [String]::Format("{0}{1}",$applicationName,"DeploymentManifest.xml")

$deploymentManifestFile = Get-ChildItem -Path $TfsSourceFolder -Filter $deploymentManifestFileName -Recurse -ErrorAction SilentlyContinue
if ($deploymentManifestFile){
    write-host "$deploymentManifestFileName found."
	$deploymentManifestXml = [xml] (Get-Content -Path $deploymentManifestFile.FullName)
	$deploymentManifestXml.SelectNodes("//DeploymentManifest/commonDeployment").ChildNodes  | where {$_.NodeType -ne "Comment"} | foreach {
		$currentAction = $_
		switch ($currentAction.Name){
			"deployResourceFolder"{
				$sourceFolder=$currentAction.Attributes.GetNamedItem("tfsSourceFolder").Value
				$includeFiles=$currentAction.Attributes.GetNamedItem("include").Value

				$Folder = Get-ChildItem $TfsSourceFolder -Recurse | Where-Object { $_.PSIsContainer -and $_.FullName.EndsWith($SourceFolder)}
                $destinationPath = Join-Path -Path $TfsStagingFolder -ChildPath $sourceFolder
                $copiedItems = Copy-Item $Folder.FullName -Destination $destinationPath -Filter $includeFiles -Recurse -Force -PassThru
			}
			default {
				Write-Verbose "Action $($currentAction.Name) is not (yet) implemented."
			}
        }
	}
}
else{
    write-host "$deploymentManifestFileName not found."
}
