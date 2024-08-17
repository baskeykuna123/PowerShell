Param($Version,$Environment,$ApplicationName='Cleva')
Clear

if(!$Version){
	$Version='36.19.10.0'
	$Environment="DCORP"
	$ApplicationName='ClevaV14'
}
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

Write-host "Deploying MPAR files for Version $Version on $Environment"
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
$Release="R"+$Version.split('.')[0]

$sourcepath=$Global:ClevaSourcePackages
if($ApplicationName -ieq 'ClevaV14'){
	$sourcepath=$Global:ClevaV14SourcePackages
}
write-host $sourcepath
$latestVersionmparFolder=Join-Path $sourcepath -ChildPath "$Release\$version\batch\$Environment\pars\"
$mparsharepath=[string]::Format("{0}{1}\Cleva\BatchProcessing\MparFiles\",$global:DfsUserShareRootPath,$Environment)


Write-Host "MPAR File Source      :" $latestVersionmparFolder
Write-Host "MPAR File destination :" $mparsharepath


if(-not (Test-path Filesystem::$mparsharepath ) -or -not (Test-path Filesystem::$latestVersionmparFolder)){
	Write-Host "Please verify the Source and destination paths of mpar files"
	Exit 1
}
Get-ChildItem Filesystem::"$latestVersionmparFolder*" -Recurse -Force | foreach {
	Write-host "Uploading MPAR : " $_.Name
	copy-item Filesystem::$($_.FullName) -destination Filesystem::$mparsharepath -Recurse -Force
}



