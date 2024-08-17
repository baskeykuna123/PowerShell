# 2020-02-03 : Luc Mercken 
# TALK : artefacts which are not included in the build.pl and belonging to a release deployment
#        are put together on the release packagages folder, source is RoundTable deployments
#        From this central point they deployed to I-A-P
#        Citrix folder, Db-server (001) and Batch-server (003)
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-12-30 : Luc Mercken : OE117 version, servernames=DNS Alias, folder names, citrix folder
#
# 2021-02-17 : Luc Mercken : not all of artefacts should be copied to client folders,  because this is a extract from GIT
#
# 2021-04-27 : Luc Mercken : TALKOLAP and TALKWS added
# 2021-04-28 : Luc Mercken : Dcorp artefacts not in packages  but on the build-server
# 2021-05-27 : Luc Mercken : Ecorp added,  there is no Ecorp batch-server,  Ecorp is on the Acorp batch-server in a different sources folder
# 2021-06-02 : Luc Mercken : also deploy to the build-server local client sources (find : Build server)
# 2021-10-27 : Luc Mercken : function LogWrite_Host
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



if(!$Environment){ $Environment="DCORP"}   #if no environment, then allways DCORP

# --------------------------------------------------------------------------------------------------------- #
#                        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#                                      SOURCES are located on packages folder              TEST  folders find test
#                        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#

# --------------------------------------------------------------------------------------------------------- #

#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


#----------------------------------------------------------------------------------------------------------------------
# Getting ReleaseNumber ( VersionNumber,  not needed at this moment )


$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )


$Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")
$Release = $($node.Version).split('.')[0]
$Version=$Node.Version

LogWrite_Host " "
LogWrite_Host " "

if ($Environment -ne "DCORP" -and $Environment -ne "ECORP") {
    LogWrite_Host "Release     : $Release         Version : $Version "
    LogWrite_Host " "
    LogWrite_Host " "
}

                                                                       

if ($Environment -eq "DCORP") {

       $PackageFolder_TALK="E:\GitSources\CleanUp\CleanUp_TALK_Develop" 
       $PackageFolder_TALKWS="E:\GitSources\CleanUp\CleanUp_TALKWS_Develop" 
       $PackageFolder_TALKOLAP="E:\GitSources\CleanUp\CleanUp_TALKOLAP_Develop" 
}
elseif ($Environment -eq "ECORP") {

       $PackageFolder_TALK="E:\GitSources\CleanUp\CleanUp_TALK_Emergency" 
       $PackageFolder_TALKWS="E:\GitSources\CleanUp\CleanUp_TALKWS_Emergency" 
       $PackageFolder_TALKOLAP="E:\GitSources\CleanUp\CleanUp_TALKOLAP_Emergency" 
}
else {
                                                                              
       $PackageFolder_TALK="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117\R" + $release + "\TALK"
       $PackageFolder_TALKWS="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117\R" + $release + "\TALKWS"
       $PackageFolder_TALKOLAP="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117\R" + $release + "\TALKOLAP"

                                                                              #TEST  TEST  TEST
       #$PackageFolder_TALK="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117_TEST\R" + $release + "\TALK"
       #$PackageFolder_TALKWS="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117_TEST\R" + $release + "\TALKWS"
       #$PackageFolder_TALKOLAP="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117_TEST\R" + $release + "\TALKOLAP"

}
#----------------------------------------------------------------------------------------------------------------------
# Check if package folders exists
# 
if (Test-Path $PackageFolder_TALK) {
    LogWrite_Host "Artefacts folder  TALK      is present  :  $PackageFolder_TALK"
}
else {
      
      LogWrite_Host "  Artefacts folder  TALK  is NOT PRESENT "
      LogWrite_Host $PackageFolder_TALK
      exit 0
}
LogWrite_Host " "

if (Test-Path $PackageFolder_TALKWS) {
    LogWrite_Host "Artefacts folder  TALKWS    is present  :  $PackageFolder_TALKWS"
}
else {
      
      LogWrite_Host "  Artefacts folder  TALKWS  is NOT PRESENT "
      LogWrite_Host $PackageFolder_TALKWS
      exit 0
}
LogWrite_Host " "

if (Test-Path $PackageFolder_TALKOLAP) {
    LogWrite_Host "Artefacts folder  TALKOLAP  is present  :  $PackageFolder_TALKOLAP"
}
else {
      
      LogWrite_Host "  Artefacts folder  TALKOLAP  is NOT PRESENT "
      LogWrite_Host $PackageFolder_TALKOLAP
      exit 0
}
LogWrite_Host " "

#----------------------------------------------------------------------------------------------------------------------

$PackageSubFolder_TALK=@()
get-childitem -path $PackageFolder_TALK       -Directory | foreach-object { $PackageSubFolder_TALK+=$_.Name }

$PackageSubFolder_TALKWS=@()
get-childitem -path $PackageFolder_TALKWS     -Directory | foreach-object { $PackageSubFolder_TALKWS+=$_.Name }

$PackageSubFolder_TALKOLAP=@()
get-childitem -path $PackageFolder_TALKOLAP   -Directory | foreach-object { $PackageSubFolder_TALKOLAP+=$_.Name }

#----------------------------------------------------------------------------------------------------------------------

# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
<#
$SaveEnvironment=$Environment

if ($Environment -eq "ECORP") {    
    $Environment = "ACORP" 
}

#retrieve the User and password from the DB 
#$Userid=get-Credentials -Environment $Environment -ParameterName  "TALKServerUser"
#$Pwd=get-Credentials -Environment $Environment -ParameterName  "TALKServerPassword"

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

#----------------------------------------------------------------------------------------------------------------------
#
    #Application Server Locations

                                                                                 
    $App_DeploymentFolder=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources",$Environment)
    $App_DeploymentFolder_TALK=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources\Talk\MncafeAc",$Environment)
    $App_DeploymentFolder_TALKWS=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources\TalkWS",$Environment)
    $App_DeploymentFolder_TALKOLAP=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources\TalkOlap",$Environment)


    #Batch Server Locations
    
    if ($Environment -eq "ECORP"){
          $Batch_DeploymentFolder_TALK=[string]::Format("\\Life-{0}-Talk-Batch-BE.balgroupit.com\E$\Sources_Ecorp\Talk\MncafeAc","ACORP")
    }
    else {                                                                                                
          $Batch_DeploymentFolder_TALK=[string]::Format("\\Life-{0}-Talk-Batch-BE.balgroupit.com\E$\Sources\Talk\MncafeAc",$Environment)
    }

    #Citrix Client TransferLocations
                                                                                       
    $Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-RZ3\MnCafeAc",$global:TransferShareRoot,$Environment)
    if ($Environment -ieq "PCORP") {                                                                                           
        $Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-Current\MnCafeAc",$global:TransferShareRoot,$Environment)
    }


    #Build Server
    $Build_DeploymentFolder_TALK=[string]::Format("\\svw-be-tlkbd002.balgroupit.com\E$\Client_Sources\{0}\Talk\MncafeAc",$Environment)



 <#                                                                                # TEST
    $App_DeploymentFolder=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources-TEST",$Environment)
    $App_DeploymentFolder_TALK=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources-TEST\Talk\MncafeAc",$Environment)
    $App_DeploymentFolder_TALKWS=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources-TEST\TalkWS",$Environment)
    $App_DeploymentFolder_TALKOLAP=[string]::Format("\\Life-{0}-Talk-App-BE.balgroupit.com\F$\Sources-TEST\TalkOlap",$Environment)

    #Batch Server Locations
                                                                                                    # TEST
    $Batch_DeploymentFolder_TALK=[string]::Format("\\Life-{0}-Talk-Batch-BE.balgroupit.com\E$\Sources-TEST\Talk\MncafeAc",$Environment)

    #Citrix Client TransferLocations
                                                                                       # TEST
    $Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-RZ3\MnCafeAc-TEST",$global:TransferShareRoot,$Environment)
    if ($Environment -ieq "PCORP") {
                                                                                           # TEST
        $Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-Current\MnCafeAc-TEST",$global:TransferShareRoot,$Environment)
    }
#>

LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "App Server TALK     :  $App_DeploymentFolder_TALK "
LogWrite_Host "App Server TALKWS   :  $App_DeploymentFolder_TALKWS "
LogWrite_Host "App Server TALKOLAP :  $App_DeploymentFolder_TALKOLAP "
LogWrite_Host "Batch Server        :  $Batch_DeploymentFolder_TALK "
LogWrite_Host "Build Server        :  $Build_DeploymentFolder_TALK "
LogWrite_Host "Citrix              :  $Citrix_DeploymentFolder "
LogWrite_Host " "
LogWrite_Host " "




# =================================================================================================================================
# deployment source folders and attributes

#Citrix
# Connecting to share with the user

LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "Deploying To Citrix : $Citrix_DeploymentFolder "
LogWrite_Host " "

& net use $Citrix_DeploymentFolder /user:$($userid) $($pwd)

# ---------------------------------------------------------
# no need to copie "config" folder in  Citrix folders     !
# ---------------------------------------------------------
foreach ($Folder in $PackageSubFolder_TALK) {
         if ($Folder -ne "Config") {
             $CopyFolder = $PackageFolder_TALK + "\" + $Folder
             LogWrite_Host "     Copy Folder Citrix : $CopyFolder "
             Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$Citrix_DeploymentFolder -Force -recurse #-WhatIf
         }
}



#App Server ,  Batch Server 
#Connecting to share with the user
LogWrite_Host " "
LogWrite_Host "Deploy Servers START"

LogWrite_Host " " 
LogWrite_Host " "
LogWrite_Host "Deploying To Application Server : $App_DeploymentFolder_TALK   " 
LogWrite_Host "Deploying To Batch Server       : $Batch_DeploymentFolder_TALK "
LogWrite_Host "Deploying To Build Server       : $Build_DeploymentFolder_TALK "
LogWrite_Host " "

& net use $App_DeploymentFolder /user:$($userid) $($pwd)
& net use $Batch_DeploymentFolder_TALK /user:$($userid) $($pwd)


foreach ($Folder in $PackageSubFolder_TALK) {

         $CopyFolder = $PackageFolder_TALK + "\" + $Folder

         LogWrite_Host "     Copy Folder TALK : $CopyFolder "

         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$App_DeploymentFolder_TALK -Force -recurse #-WhatIf
         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$Batch_DeploymentFolder_TALK -Force -recurse #-WhatIf
         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$Build_DeploymentFolder_TALK -Force -recurse #-WhatIf
}

LogWrite_Host " "
LogWrite_Host " "

foreach ($Folder in $PackageSubFolder_TALKWS) {

         $CopyFolder = $PackageFolder_TALKWS + "\" + $Folder

         LogWrite_Host "     Copy Folder TALKWS : $CopyFolder "

         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$App_DeploymentFolder_TALKWS -Force -recurse #-WhatIf  
}

LogWrite_Host " "
LogWrite_Host " "

foreach ($Folder in $PackageSubFolder_TALKOLAP) {

         $CopyFolder = $PackageFolder_TALKOLAP + "\" + $Folder

         LogWrite_Host "     Copy Folder TALKOLAP : $CopyFolder "

         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$App_DeploymentFolder_TALKOLAP -Force -recurse #-WhatIf        
}


LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "Deploy Servers ENDED"

& net use * /d /yes | Out-Null
