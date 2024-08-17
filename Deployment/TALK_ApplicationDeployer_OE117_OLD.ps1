# 2019-07-02 : Luc Mercken : added Ecorp
# 2019-12-05 : Luc Mercken : start deploy IAP from packages folder (Release_Version folder)
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-08-12 : Luc Mercken : added Version_Title, a update of the application Title
# 2020-12-30 : Luc Mercken : OE117 version, citrix folder, foldernames, servernames=DNS alias
#
#
#                                                                               
Param($Environment)

Clear

                                    # WHATIF   in copie statement  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if(!$Environment){ $Environment="DCORP" }  #if no environment, then allways DCORP

#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#
#----------------------------------------------------------------------------------------------------------------------
# Getting ReleaseNumber and VersionNumber in case of a IAP deployment

if($Environment -eq "ICORP" -Or $Environment -eq "ACORP" -Or $Environment -eq "PCORP") {
    $xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )


    $Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")
    $Release = $($node.Version).split('.')[0]
    $Version=$Node.Version
    Write-Host "Release : " $Release "          Version : " $Version
} 
  
#----------------------------------------------------------------------------------------------------------------------
# Source folder of the build.pl,  central destination folder(package, Talk, Release and Version
# BuildSourceFile : Depending I-A-P,  Dcorp,  Ecorp
#
if($Environment -match "DCORP"){
	$BuildSourceFile="\\svw-be-tlkbd002.balgroupit.com\E$\GitSources\Scripts\Build_Scripts\Develop\Latest\build.pl"
}
else {
      $PackagesFolder="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117"

      $ReleaseBuildFolder=$PackagesFolder + "\R" + $Release + "\Build"
      $BuildSourceFile= $ReleaseBuildFolder + "\build.pl"
}

#
#--------------------------------------------------------------------------------------------------------------------------
<#
if($Environment -match "ECORP"){
	$BuildSourceFile="\\svw-be-tlkbd002.balgroupit.com\E$\Scripts\Build_Scripts\Ecorp\Latest\build.pl"
}
#>

#----------------------------------------------------------------------------------------------------------------------

# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !

$SaveEnvironment=$Environment

if ($Environment -eq "ECORP") {    
    $Environment = "ACORP" 
}


$serval=$Environment[0]

<#
#retrieve the User and password from the DB 
$Userid=get-Credentials -Environment $Environment -ParameterName  "TALKServerUser"
$Pwd=get-Credentials -Environment $Environment -ParameterName  "TALKServerPassword"
#>

$Environment=$SaveEnvironment

# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !

#$Environment="ICORP"
switch($Environment){
	"DCORP" {				
				$userid="balgroupit\L001234"
				$pwd="Dp6unFoU" #| ConvertTo-SecureString -asPlainText -Force
			}
	"ICORP" {				
				$userid="balgroupit\L001235"
				$pwd="b5VfDZRN" #| ConvertTo-SecureString -asPlainText -Force
			}
	"ACORP" {				
				$userid="balgroupit\L001097"
				$pwd="Basler09" #| ConvertTo-SecureString -asPlainText -Force
			}
	"ECORP" {				
				$userid="balgroupit\L001097"
				$pwd="Basler09" #| ConvertTo-SecureString -asPlainText -Force
			}
	"PCORP" {
				
				$userid="balgroupit\L001129"
				$pwd="PMerc_11" #| ConvertTo-SecureString -asPlainText -Force
			}
}


#--------------------------------------------------------------------------------------------------------------------------
# check if needed file is present,  if not stop procedure
#
if(-not(Test-Path FileSystem::$BuildSourceFile)){
	Write-Host 	"The Build Source File not found : $BuildSourceFile"
	Write-Host 	"Deployment Failed"
	Exit 1
}
write-host "BuildSourceFile : " $BuildSourceFile

#--------------------------------------------------------------------------------------------------------------------------

#citrix Client TransferLocations
$DeloymentFolders=@()

if ($Environment -ieq "PCORP") {
    $DeloymentFolders+=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-Current",$global:TransferShareRoot,$Environment)
}
else {
      $DeloymentFolders+=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-RZ3",$global:TransferShareRoot,$Environment)
}


#deployment Servers
$DeloymentFolders+=[string]::Format("\\Life-{0}-Talk-Batch-BE.balgroupit.com\E$\Sources\Talk",$Environment)
$DeloymentFolders+=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources\Talk",$Environment)





foreach($folder in $DeloymentFolders){
	#Connecting to share with the user
	Write-Host 	 "Deploying To : $folder"
	& net use $folder /user:$($userid) $($pwd)
	Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$folder -Force #-WhatIf
	
}

& net use * /d /yes | Out-Null


