# 2019-07-02 : Luc Mercken : added Ecorp
# 2019-12-05 : Luc Mercken : start deploy IAP from packages folder (Release_Version folder)
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-08-12 : Luc Mercken : added Version_Title, a update of the application Title
# 2020-12-30 : Luc Mercken : OE117 version, citrix folder, foldernames, servernames=DNS alias
# 2021-05-27 : Luc Mercken : Ecorp added,  there is no Ecorp batch-server,  Ecorp is on the Acorp batch-server in a different sources folder
# 2021-06-02 : Luc Mercken : also deploy to the build-server local client sources (find : Build server)
# 2021-10-27 : Luc Mercken : function LogWrite_Host
#
#
#                                                                               
Param($Environment)



#--------------------------------------------------------------------------------------
#                                      Functions
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#     Write-Host_with_TimeStamp Function
#--------------------------------------------------------------------------------------
Function LogWrite_Host {

    param ($LogString)

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    Write-Host $TimeStamp "     " $LogString
}


#--------------------------------------------------------------------------------------


Clear

                                    # WHATIF   in copie statement  !!!!!!!!!!!!!!!NOT in Use !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
    #Write-Host "Release : " $Release "          Version : " $Version
    LogWrite_Host "Release : $Release           Version : $Version"
} 
  
#----------------------------------------------------------------------------------------------------------------------
# BuildSourceFile : Depending I-A-P,  Dcorp,  Ecorp
# IAP : Source folder of the build.pl,  central destination folder(package, Talk, Release and Version
# D-E : on build server,  E:\GitSources\Scripts\Build_Scripts\D or E\Latest\
#

if($Environment -match "DCORP"){

	    $BuildSourceFile="\\svw-be-tlkbd002.balgroupit.com\E$\GitSources\Scripts\Build_Scripts\Develop\Latest\build.pl"
}
elseif($Environment -match "ECORP"){

	    $BuildSourceFile="\\svw-be-tlkbd002.balgroupit.com\E$\GitSources\Scripts\Build_Scripts\Emergency\Latest\build.pl"
}
else {
        $PackagesFolder="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117"

        $ReleaseBuildFolder=$PackagesFolder + "\R" + $Release + "\Build"
        $BuildSourceFile= $ReleaseBuildFolder + "\build.pl"
}



#----------------------------------------------------------------------------------------------------------------------

# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
<#
$SaveEnvironment=$Environment

if ($Environment -eq "ECORP") {    
    $Environment = "ACORP" 
}

#retrieve the User and password from the DB 
$Userid=get-Credentials -Environment $Environment -ParameterName  "TALKServerUser"
$Pwd=get-Credentials -Environment $Environment -ParameterName  "TALKServerPassword"

$Environment=$SaveEnvironment
#>

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
	LogWrite_Host "The Build Source File not found : $BuildSourceFile"
	LogWrite_Host "Deployment Failed"
	Exit 1
}

LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "BuildSourceFile : $BuildSourceFile"

#--------------------------------------------------------------------------------------------------------------------------

#citrix Client TransferLocations
$DeploymentFolders=@()

if ($Environment -ieq "PCORP") {
    $DeploymentFolders+=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-Current",$global:TransferShareRoot,$Environment)
}
else {
      $DeploymentFolders+=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-RZ3",$global:TransferShareRoot,$Environment)
}



#
#Batch Server
#Acorp and Ecorp are on the same batch-server,  so Ecorp on a different location instead of default folder
if ($Environment -eq "ECORP") {
      $DeploymentFolders+=[string]::Format("\\Life-{0}-Talk-Batch-BE.balgroupit.com\E$\Sources_Ecorp\Talk","ACORP")
}
else {
      $DeploymentFolders+=[string]::Format("\\Life-{0}-Talk-Batch-BE.balgroupit.com\E$\Sources\Talk",$Environment)
      }


#Application Server
$DeploymentFolders+=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources\Talk",$Environment)


#Build Server 
#$DeploymentFolders+=[string]::Format("\\svw-be-tlkbd002.balgroupit.com\E$\Client_Sources\{0}\Talk",$Environment)
$DeploymentBuildServer=[string]::Format("\\svw-be-tlkbd002.balgroupit.com\E$\Client_Sources\{0}\Talk",$Environment)

LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "Copy Start"


foreach($Folder in $DeploymentFolders){
	#Connecting to share with the user
	
    LogWrite_Host "Deploying To :  $Folder "

	& net use $Folder /user:$($userid) $($pwd)
	Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$Folder -Force #-WhatIf
	
}


& net use * /d /yes | Out-Null


#BuildServer
LogWrite_Host " "
LogWrite_Host "Deploying To : $DeploymentBuildServer"
Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$DeploymentBuildServer -Force #-WhatIf

LogWrite_Host " "
LogWrite_Host "Copy Stop"
LogWrite_Host " "


