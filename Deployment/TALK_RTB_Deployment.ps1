# Luc Mercken
# 2019-11-13
# 
# get from release manifest the Version number Talk
# using a template (Template_RTB_Jenkins_Menu.pf ( $Template_MenuFile ) )  to change input parameters needed voor RTB Deployment
#  ( -param "RelDir=RelFolder,RelNum=RelVersion" )
#
# pf-file used = RTB_Jenkins_Menu.pf ( $Run_MenuFile )
#
# starting a command file ( E:\BuildScripts\RTB_Deploy\Start.bat ) which executed an OE program ( Make_Release_Deploy.p )
# output and report are dropped in version folder ( \\balgroupit.com\appl_data\BBE\Packages\TALK\ )
#
# Pf-files, program, command file can be found in : E:\BuildScripts\RTB_Deploy (build server, SVW-BE-TLKBP001) 
#
# (20191118) : Release Report is inserted in Jenkins console output
#              fine-tuning variable names  
#----------------------------------------------------------------------------------------------------------------------


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
# Destination Objects in Deployment,  Source of the template


$TemplateFolder="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Templates\Talk\"
$PackagesFolder="\\balgroupit.com\appl_data\BBE\Packages\TALK"

$RelFolder=$PackagesFolder + "\R" + $Release
# $RelFolder="E:\DEV\Talk3\DEPLOY\R" + $Release
write-host "Release Folder : "$RelFolder

#----------------------------------------------------------------------------------------------------------------------
# Check if Release Folder exist,  if not then create it


if (Test-Path $Relfolder) {
    write-host "  Release Folder is present"
}
else {
      New-Item -ItemType Directory -Path $Relfolder -ErrorAction Stop | Out-Null
      write-host "  Release Folder is created"
      start-sleep -seconds 5
}


#----------------------------------------------------------------------------------------------------------------------
# a menu.pf file is generated from a template, some variables are replaced by actual data
# menu.pf : connect to RTB db, executing OE_program


$Template_MenuFile=join-path $TemplateFolder -ChildPath "Template_RTB_Jenkins_Menu.pf"
# $Template_MenuFile=join-path "E:\BuildScripts\RTB_Deploy\" -ChildPath "Template_RTB_Jenkins_Menu.pf"


$Run_MenuFile=join-path "E:\BuildScripts\RTB_Deploy\" -ChildPath "RTB_Jenkins_Menu.pf"


if (Test-Path $Run_MenuFile) {
    Remove-Item $Run_MenuFile -force -ErrorAction Ignore
}

   
(Get-Content -Path $Template_MenuFile) | Foreach-Object {
    $_ -replace 'RelFolder', $RelFolder `
       -replace 'RelVersion', $Version `       
     } | Set-Content -path $Run_MenuFile


#----------------------------------------------------------------------------------------------------------------------
# Executing RTB Release_Deploy


$BatFile="E:\BuildScripts\RTB_Deploy\Start.bat"
cmd.exe /C $Batfile


#----------------------------------------------------------------------------------------------------------------------
# we insert release report into Jenkins console output


$ActualReport=$RelFolder + "\" + $Version + "\" + $Version + ".txt"

get-content $ActualReport