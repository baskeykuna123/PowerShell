PARAM($Environment)
clear


if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if(!$Environment){
	$Environment="PCORPTEST"
}


$Databasestochecked="EAI921,EX921,Peach_Data,PTMercator"
$appname="MyBaloiseClassic"
$Env=$Environment

if($Environment -ieq "PCORPTEST"){$Env="PCORP"}

$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Env']/Application[@Name='MyBaloiseClassic']")
$CurrentVersion=$node.Version
$PerviousVersion=$node.PreviousVersion
$ClassicBaseversion=$node.Version.Split('.')[0] + '.' +$node.Version.Split('.')[1]
if($PerviousVersion.Split('.')[1] -ne $CurrentVersion.split('.')[1]){
	$newRelease=$true
}

$DBScriptBuildFolder=[string]::Format("\\shw-me-pdtalk51\Released Deliverables\MercatorNet Release {0}\Database\",$ClassicBaseversion)
$DBScriptDeploymentFolder="\\shw-me-pdtalk51\F$\DatabaseDeployment\$Environment\"
$DBScriptDeploymentFolder="\\shw-me-pdtalk51\F$\DatabaseDeployment\Test"
$CurrentVersionDeploymentFolder=join-path $DBScriptDeploymentFolder -ChildPath $CurrentVersion

remove-item Filesystem::$CurrentVersionDeploymentFolder -Force -Recurse -ErrorAction Ignore

$CurretVersionSource=Join-Path $DBScriptBuildFolder -ChildPath $CurrentVersion
Copy-Item Filesystem::$CurretVersionSource -Destination Filesystem::$DBScriptDeploymentFolder -Force -Recurse


$DBbatchfilePath=[string]::Format("{0}\{1}_db_batch_main.bat",$CurrentVersionDeploymentFolder,$CurrentVersion)
$batchfilecontent=Get-Content 	Filesystem::$DBbatchfilePath

if($newRelease){
	$dbfolderlist=Get-ChildItem filesystem::$DBScriptBuildFolder | Where-Object { $_.PSIsContainer }| sort CreationTime
}

$dbfolderlist
 #Write-Host "Checking DB folder :"  $dbfolder
foreach($fl in $ROOSFolders.Split(',')){
	foreach($dbfolder in $dbfolderlist)
	{
		$folder=$dbfolder.FullName+"\"+"$fl"+"\"
		$Roosfl=Get-ChildItem Filesystem::$folder -Directory -Include *ROOS* -Recurse 
		if($Roosfl -ne $null){
			
			$RoosBatch=Get-ChildItem Filesystem::$folder  -filter "*ROOS.bat*" -File
			$CurrentRoosPath=join-path $DBScriptDeploymentFolder -ChildPath "$($CurrentVersion)\$($fl)"
			$newfilename=$CurrentVersion+"_"+$fl+"_ROOS.bat"
			$CurrentRoosBatfile=join-path $DBScriptDeploymentFolder -ChildPath "$($CurrentVersion)\$($fl)\$($newfilename)"
			$Searchtext="REM $fl ROOS"
			$ROOScall=[string]::Format("call {0} > {1}_{2}_ROOS_output_%domain%.txt",$newfilename,$CurrentVersion,$fl)
			Write-Host "======================================================================="
			Write-Host "Roos Found in $dbfolder"
			Write-Host "ROOSSourceBatchFile   :" $RoosBatch.FullName
			Write-Host "CurrentROOSBatchFile  :" $CurrentRoosBatfile
			Write-Host "ROOS SearchText       :" $Searchtext
			Write-Host "ROOS Call Script      :" $ROOScall
			Write-Host "=======================================================================`n`r"
			Copy-Item Filesystem::$($Roosfl.FullName)  -Destination Filesystem::$CurrentRoosPath -Force -Recurse
			foreach($line in [System.IO.File]::ReadAllLines($RoosBatch.FullName)){
				add-content Filesystem::$CurrentRoosBatfile -Value $line -Force
			}
			
		}
	}
		$batchfilecontent=$batchfilecontent -replace $Searchtext,$ROOScall
}

Set-Content Filesystem::$DBbatchfilePath -Value $batchfilecontent




	
