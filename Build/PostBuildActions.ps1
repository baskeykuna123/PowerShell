# Enable -Verbose option
[CmdletBinding()]

param([String]$TfsSourceFolder,[String]$TfsStagingFolder,[String]$BuildID)

if(!$TfsStagingFolder){
$TfsSourceFolder = "E:\TFSBuild\55\s"
$TfsStagingFolder = "E:\TFSBuild\55\a"
$BuildID="DEV_TaskCreateEngine_20200427.2"
}
#$VerbosePreference = "Continue"
#$VerbosePreference = "SilentlyContinue"

Write-Verbose "TfsSourceFolder= $TfsSourceFolder"
Write-Verbose "TfsStagingFolder= $TfsStagingFolder"
Write-Verbose "BuildID= $BuildID"

Write-Verbose "start reading AfterBuildActions.xml"

$BuildVersion = $BuildID.Split("_")[$BuildID.Split("_").Length - 1]
$BuildDefenitionname = $BuildID.Replace("_" + $BuildVersion , "")
$applicationName = $BuildDefenitionname.Split("_")[$BuildDefenitionname.Split("_").Length - 1]
$afterBuildActionsFileName = [String]::Format("{0}{1}",$applicationName,"AfterBuildActions.xml")

$afterBuildActionsFile = Get-ChildItem -Path $TfsSourceFolder -Filter $afterBuildActionsFileName -Recurse -ErrorAction SilentlyContinue
if (! $afterBuildActionsFile){
	Write-Warning  "$($afterBuildActionsFileName) not recursively found in $($TfsSourceFolder)"
	exit 1
}

$afterBuildActionsXml = [xml] (Get-Content -Path $afterBuildActionsFile.FullName)
$afterBuildActionsXml.SelectNodes("AfterBuildActions").ChildNodes  | where {$_.NodeType -ne "Comment"} | foreach {
	$currentAction = $_
	switch ($currentAction.Name){
        "CopyBuildOutputFolder"{
         	$sourceProject = $currentAction.Attributes.GetNamedItem("sourceProject").Value
			$destinationProject = $currentAction.Attributes.GetNamedItem("destinationProject").Value
			$SourceBuildoutputfolder=$currentAction.Attributes.GetNamedItem("SourceBuildoutputfolder").Value
            $DestinationBuildoutputfolder=$currentAction.Attributes.GetNamedItem("DestinationBuildoutputfolder").Value
			#find sourceProject in TfsSourceFolder
			$sourceprojectFile = Get-ChildItem -Path $TfsSourceFolder -Include $sourceProject -Recurse
			if ( ! (Test-Path $sourceprojectFile)){
				Write-Error "$($sourceProject) not recursively found in $($TfsSourceFolder)"
				exit 1
			}
			#find sourceProjectSubPath under sourceProject folder
             $SourceFolder=(Get-ChildItem $($sourceprojectFile.DirectoryName) -filter $SourceBuildoutputfolder -Force -Recurse).FullName
			
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
			$destinationprojectFolders
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
			
			$destinationPath = Join-Path -Path $deepestPath -ChildPath $DestinationBuildoutputfolder
			Write-Verbose "Destination folder found at $($destinationPath)"
			$sourceFolder
            $destinationPath
			$copiedItems = Copy-Item $sourceFolder\* -Destination $destinationPath -Filter $includeFiles -Recurse -Force -PassThru
			Write-Verbose "$($copiedItems.Count) items copied.."
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
             $SourceFolder=(Get-ChildItem $($sourceprojectFile.DirectoryName) -filter $sourceProjectSubPath -Force -Recurse).FullName
			
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
                    $_.FullName		
                    $destinationPath
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
			Write-Verbose "Action $($currentAction.Name) is not yet implemented."
		}
	}
}
