param($StagingDirectory,$BuildConfig,$sourceBranch,$BuildDefinitionID)

clear

if(!$StagingDirectory){
	$StagingDirectory="E:\TFSBuild\12\a"
	$BuildConfig='DEBUG'
	$sourceBranch='Baloise'
    $BuildDefinitionID='Staging_Framework'
}

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$Filesnotfound=@()
#$Packagedir=[string]::Format("{0}\{1}_{2}\{3}\",$PackageRootFolder,$BuildID.Split('_')[0],$BuildID.Split('_')[1],$BuildID.Split('_')[2])

$SourceDirectory=$StagingDirectory.Replace('a','s')
$ShareVersion=GetBuildDBVersionForTFSFramework -sourceBranch $sourceBranch -BuildDefinitionID $BuildDefinitionID -DBServer $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -UserID $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword
#version up and until 4.21 have the framework share on pdnet
#newer versions have the framework share on bldp001
[int]$major, [int]$minor = $ShareVersion.Split('.')
if( ($major -le 4) -and ($minor -le 21 ) ){
	$FrameworkSharePath=[string]::Format("\\shw-me-pdnet01\{0}_{1}_MERCATORFRAMEWORK_LATEST\",$ShareVersion,$BuildConfig)
}
else{
	$FrameworkSharePath=[string]::Format("\\svw-be-bldp001\{0}_{1}_MERCATORFRAMEWORK_LATEST\",$ShareVersion,$BuildConfig)
}

Get-ChildItem FileSystem::$FrameworkSharePath -Force -Recurse -File | foreach {
    $filepath=Get-ChildItem FileSystem::$StagingDirectory -Recurse -Filter "$($_.Name)" -File -Force | select -first 1
    if($filepath -ne $null){
        #Write-Host "Sharepath :" $_.FullName
        #Write-Host "LatetFile :" $filepath.FullName
        Copy-Item FileSystem::$($filepath.FullName) -Destination FileSystem::$($_.FullName) -Force -Verbose
    }
    else{
    $Filesnotfound+=$_
    #write-host "Not found" $_
    }
}
Write-Host "`r`n**********List of files not found in the build*******"
$Filesnotfound.FullName
Write-Host "**********List of files not found in the build*******"

#copy packages folder
Get-ChildItem $SourceDirectory -Force -Recurse -Directory -Filter "Packages" | ForEach {
    Copy-Item FileSystem::$($_.FullName) -Destination FileSystem::$($FrameworkSharePath) -Force -Verbose -Recurse
}