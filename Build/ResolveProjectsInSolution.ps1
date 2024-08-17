# Enable -Verbose option
[CmdletBinding()]

param([String]$SolutionName,[String]$TfsSourceFolder)

#$SolutionName="Mercator.Esb.Framework.sln"
#$TfsSourceFolder ="F:\TfsAgent\1\s"
#$VerbosePreference = "Continue"
#$VerbosePreference = "SilentlyContinue"

cls

Write-Verbose "SolutionName  $SolutionName"
Write-Verbose "TfsSourceFolder $TfsSourceFolder"


$OldLocation = Get-Location
$MSBuildAssembly="C:\Program Files (x86)\Reference Assemblies\Microsoft\MSBuild\v14.0\Microsoft.Build.dll"
$dummy=[Reflection.Assembly]::LoadFile($MSBuildAssembly)

Get-ChildItem -Path $TfsSourceFolder  -Include $SolutionName -Recurse | foreach{
	$SolutionPath = $_.FullName
}

$solutionFileAttributes = [IO.File]::GetAttributes($SolutionPath)
$Solution = [Microsoft.Build.Construction.SolutionFile]::Parse($SolutionPath)
$SolutionFile = Get-ChildItem -Path $SolutionPath
$SolutionFolder = $SolutionFile.DirectoryName
[IO.File]::SetAttributes($SolutionPath, "Normal")

$projectCollection = new-object Microsoft.Build.Evaluation.ProjectCollection

$Solution.ProjectsInOrder | Where-Object {$_.ProjectType -ne "SolutionFolder"} | ForEach-Object {

	Set-Location $SolutionFolder
	$currentProjectRelPath = $_.RelativePath
	$projectFileFullName = $_.AbsolutePath
	
	if (! (test-path $_.AbsolutePath) ) {
		$arrSplitPath = $_.RelativePath.Split("\")
		$projectName = $arrSplitPath[$arrSplitPath.Count-1]
		Write-Verbose "Relative path for $projectName not correct. Trying to find the project.."
		Get-ChildItem -Path $TfsSourceFolder  -Include $projectName -Recurse | foreach{
			$projectFileFullName = $_.FullName
		}

		$NewRelPath = Resolve-Path $projectFileFullName -Relative
		
		Write-Verbose "Wrong relative path: ""$currentProjectRelPath"""
		Write-Verbose "will be replaced by ""$NewRelPath"""		
		
		$currentProjectRelPath = $currentProjectRelPath -replace ('\\','\\')
		$content = [IO.File]::ReadAllLines($SolutionPath) -replace $currentProjectRelPath,$NewRelPath 
		[IO.File]::WriteAllLines($SolutionPath, $content)		
	}
	
	[string]$projectfilecontent= Get-Content $projectFileFullName
	if($projectfilecontent -inotlike "*Microsoft.NET.Sdk*"){
		$project = $projectCollection.LoadProject($projectFileFullName)
		Set-Location $project.DirectoryPath
	
		$project.get_AllEvaluatedItems() | foreach {
	
		$fileattributes = [IO.File]::GetAttributes($projectFileFullName)
		[IO.File]::SetAttributes($projectFileFullName, "Normal")		
		$projectRefFileFullName = [String]::Empty
		
		if ($_.ItemType -like "*projectreference*") {
			if (! (test-path $_.EvaluatedInclude)){
				$arrSplitPath = $_.EvaluatedInclude.Split("\")
				$projectName = $arrSplitPath[$arrSplitPath.Count-1]
				Get-ChildItem -Path $TfsSourceFolder  -Include $projectName -Recurse | foreach{
					$projectRefFileFullName = $_.FullName
				}
				
				$NewRelPath = Resolve-Path $projectRefFileFullName -Relative
				$currentProjectRelPath = $_.EvaluatedInclude -replace ('\\','\\')
				$content = [IO.File]::ReadAllLines($projectFileFullName) -replace $currentProjectRelPath,$NewRelPath 
				[IO.File]::WriteAllLines($projectFileFullName, $content)	
				
			}
		}
		elseif ( ($_.ItemType -like "Reference") -and ($_.DirectMetadataCount -gt 0) ) {
			if   ($_.DirectMetadata.ContainsKey("HintPath") ){
				$hinthPath = $_.DirectMetadata["HintPath"].EvaluatedValue
				if ($hinthPath -notlike "*\packages\*"){
					if (! (test-path $hinthPath)){
						$arrSplitPath = $hinthPath.Split("\")
						$projectName = $arrSplitPath[$arrSplitPath.Count-1]

						Get-ChildItem -Path $TfsSourceFolder  -Include $projectName -Recurse | foreach{
							$projectRefFileFullName = $_.FullName
						}

						if ($projectRefFileFullName -eq [String]::Empty){
							write-error "$($projectName) not found in project $($projectFileFullName)"
						}
						else {				
							$NewRelPath = Resolve-Path $projectRefFileFullName -Relative
							$currentProjectRelPath = $hinthPath -replace ('\\','\\')
							$content = [IO.File]::ReadAllLines($projectFileFullName) -replace $currentProjectRelPath,$NewRelPath
							[IO.File]::WriteAllLines($projectFileFullName, $content)	
						}
					}
				}
			}
		}
		
		[IO.File]::SetAttributes($projectFileFullName, $fileattributes)	
	}
	}
}

[IO.File]::SetAttributes($SolutionPath, $solutionFileAttributes)	
Set-Location $OldLocation