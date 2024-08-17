# Luc Mercken
# 2021-04-15
# 
# copy the build library (build.pl) to the release_Version folder (TALK)
#
# 2021-04-15 :  oe117 version,  nwe build server + folder names + sources from GIT
#----------------------------------------------------------------------------------------------------------------------

#                                                     TEST  FOLDERS     !!!!!!!!not in use now

clear

#----------------------------------------------------------------------------------------------------------------------
#loading Function

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#----------------------------------------------------------------------------------------------------------------------
# Getting ReleaseNumber and VersionNumber


$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )


$Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")
$Release = $($node.Version).split('.')[0]
$Version=$Node.Version
Write-Host "Release : " $Release "          Version : " $Version


#----------------------------------------------------------------------------------------------------------------------
# Source folder of the build.pl,  central destination folder(package, Talk, Release and Version

$SourceBuildPl="E:\GitSources\Scripts\Build_Scripts\Staging\Latest\build.pl"

                                                                   
$PackagesFolder="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117"
                                                                   

                                                                   #TEST
#$PackagesFolder="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117_TEST"
                                                                   #TEST



$ReleaseVersionFolder=$PackagesFolder + "\R" + $Release + "\" + $Version
$ReleaseBuildFolder=$PackagesFolder + "\R" + $Release + "\Build" 

#----------------------------------------------------------------------------------------------------------------------
# Check if Release Folder exist,  if not then create it
#  


if (Test-Path $ReleaseVersionFolder) {
    write-host "  Release Folder is present"
}
else {
      New-Item -ItemType Directory -Path $ReleaseVersionFolder -ErrorAction Stop | Out-Null
      write-host "  Release Folder is created"
      start-sleep -seconds 5
}

write-host "Release-Version Folder : "$ReleaseVersionFolder

#----------------------------------------------------------------------------------------------------------------------
# Copy the file Build.pl

copy-item -Path $SourceBuildPl -Destination $ReleaseVersionFolder



#----------------------------------------------------------------------------------------------------------------------
# Check if Build Folder exist,  if not then create it
#
if (Test-Path $ReleaseBuildFolder) {
    write-host "  Build Folder is present"
}
else {
      New-Item -ItemType Directory -Path $ReleaseBuildFolder -ErrorAction Stop | Out-Null
      write-host "  Build Folder is created"
      start-sleep -seconds 5
}

write-host "Build Folder : "$ReleaseBuildFolder

#----------------------------------------------------------------------------------------------------------------------
# Copy the file Build.pl

copy-item -Path $SourceBuildPl -Destination $ReleaseBuildFolder
