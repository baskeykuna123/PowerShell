# 2020-01-16 : Luc Mercken 
# Lina  TalkFrontend component :  only used in citrix environment and local development server
# 2020-02-12 : Luc Mercken : added 003_client
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-12-17 : Luc Mercken : TalkFrontEnd is changed in Lina,  more and new directories,  source of the code  is also changed
# 2020-12-28 : Luc Mercken : changes to OE117 Version and new environment of servers
# 2021-05-04 : Luc Mercken : Dcorp artefacts on build-server
# 2021-06-02 : Luc Mercken : also deploy to the build-server local client sources (find : Build server)
# 2021-09-27 : Luc Mercken : adding Ecorp
# 2021-10-27 : Luc Mercken : function LogWrite_Host
#

#                                               en  WHATIF   !!!!!!
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

LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "INPUT PARAM environment : $Environment "


if(!$Environment) {$Environment="DCORP"}      #if no environment, then allways DCORP

# --------------------------------------------------------------------------------------------------------- #
#                        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#                                      SOURCES are located on packages folder I-A-P
#                                                             build server    D 
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
# Getting ReleaseNumber (and VersionNumber,  not needed at this moment )


$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )


$Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")
$Release = $($node.Version).split('.')[0]
$Version=$Node.Version

LogWrite_Host  " "
LogWrite_Host  " "
if ($Environment -ne "DCORP" -and $Environment -ne "ECORP") {
    LogWrite_Host "Release     : $Release         Version : $Version "
    LogWrite_Host  " "
    LogWrite_Host  " "
}

$PackageFolder="\\balgroupit.com\appl_data\BBE\Packages\Talk_OE117\R" + $release + "\Lina"

if ($Environment -eq "DCORP") { 
       $PackageFolder="E:\GitSources\CleanUp\CleanUp_Lina_Develop" 
}

if ($Environment -eq "ECORP") { 
       $PackageFolder="E:\GitSources\CleanUp\CleanUp_Lina_Emergency" 
}


# Check if package folder exist
#  

if (Test-Path $PackageFolder) {
    LogWrite_Host "Package folder is present : $PackageFolder "
}
else {
      
      LogWrite_Host "  Package folder is NOT PRESENT : : $PackageFolder "
      stop
}


LogWrite_Host " "
LogWrite_Host " "


#---------------------------------------------------------------------------------------------------------------------- 
# Client : DWP-Citrix Client and Batch-Server Client (Life-xCORP-Talk-Batch-BE) and build server

$Folders_Client="Control",
                "Form",
                "Image",
                "Include",
                "Lina",
                "Manager",
                "Model",
                "ServiceAdapter"



# Application Server : (Life-xCORP-Talk-App-BE) 

$Folders_BackEndServer="Include",
                       "Lina",
                       "Manager",
                       "ServiceAdapter"

#
#---------------------------------------------------------------------------------------------------------------------- 


$BuildSourceFiles_Client=@()
foreach ($Folder in $Folders_Client) {
         $BuildSourceFiles_Client+=($PackageFolder + "\" + $Folder)        
}

$BuildSourceFiles_Server=@()
foreach ($Folder in $Folders_BackEndServer) {
         $BuildSourceFiles_Server+=($PackageFolder + "\" + $Folder)        
}



$RemoveFiles_Citrix=@()
$RemoveFiles_BatchServer=@()
$RemoveFiles_BuildServer=@()
$RemoveFiles_ApplicationServer=@()



#----------------------------------------------------------------------------------------------------------------------

#$Environment="ICORP"

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

#Application Server
$App_DeploymentFolder=[string]::Format("\\Life-{0}-Talk-App-BE\F$\Sources\Lina",$Environment)


#Batch Server
$Batch_DeploymentFolder=[string]::Format("\\Life-{0}-Talk-Batch-BE\E$\Sources\Lina",$Environment)

if ($Environment -eq "ECORP") {
    $Batch_DeploymentFolder=[string]::Format("\\Life-Acorp-Talk-Batch-BE\E$\Sources_Ecorp\Lina") 
}


#Build Server
$Build_DeploymentFolder=[string]::Format("\\svw-be-tlkbd002.balgroupit.com\E$\Client_Sources\{0}\Lina",$Environment)


#Citrix Client TransferLocations
$Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-RZ3\Lina",$global:TransferShareRoot,$Environment)

if ($Environment -ieq "PCORP") {
    $Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-Current\Lina",$global:TransferShareRoot,$Environment)
}


LogWrite_Host "Application Server      :  $App_DeploymentFolder    "
LogWrite_Host "Batch Server            :  $Batch_DeploymentFolder  "
LogWrite_Host "Build Server            :  $Build_DeploymentFolder  "
LogWrite_Host "Citrix                  :  $Citrix_DeploymentFolder "
LogWrite_Host " "
LogWrite_Host " "



#----------------------------------------------------------------------------------------------------------------------
#
& net use $Citrix_DeploymentFolder /user:$($userid) $($pwd)
& net use $App_DeploymentFolder /user:$($userid) $($pwd)
& net use $Batch_DeploymentFolder /user:$($userid) $($pwd)



#----------------------------------------------------------------------------------------------------------------------
# first remove existing destination folders and attributes,  except connections.xml

foreach ($Folder in $Folders_Client) {
         $RemoveFiles_Citrix+=($Citrix_DeploymentFolder + "\" + $Folder )
         $RemoveFiles_BatchServer+=($Batch_DeploymentFolder + "\" + $Folder )
         $RemoveFiles_BuildServer+=($Build_DeploymentFolder + "\" + $Folder )
}


foreach ($Folder in $Folders_BackEndServer) {
         $RemoveFiles_ApplicationServer+=($App_DeploymentFolder + "\" + $Folder )
         
}


LogWrite_Host "Start Delete Current "

foreach ($Remove_File in $RemoveFiles_Citrix){

         LogWrite_Host "     Deleting Citrix : $Remove_File "
         remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-whatif
}


LogWrite_Host " "
foreach ($Remove_File in $RemoveFiles_BatchServer){

         LogWrite_Host "     Deleting Batch  :  $Remove_File "
         remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-WhatIf
}


LogWrite_Host " "
foreach ($Remove_File in $RemoveFiles_BuildServer){

         LogWrite_Host "     Deleting Build : $Remove_File "
         remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-WhatIf
}


LogWrite_Host " "
foreach ($Remove_File in $RemoveFiles_ApplicationServer){

         LogWrite_Host "     Deleting App : $Remove_File "
         remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-WhatIf
}



LogWrite_Host "End Delete Current"

start-sleep -seconds 10

#----------------------------------------------------------------------------------------------------------------------
# next deployment source folders and attributes

#Citrix
# Connecting to share with the user

LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "Deploying To Citrix : $Citrix_DeploymentFolder "


foreach($BuildSourceFile in $BuildSourceFiles_Client) { 

        LogWrite_Host "     From : $BuildSourceFile " 
	    Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$Citrix_DeploymentFolder -Force -recurse #-WhatIf
}


#----------------------------------------------------------------------------------------------------------------------
#
# Batch Server

LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "Deploying To Batch Server : $Batch_DeploymentFolder "

foreach($BuildSourceFile in $BuildSourceFiles_Client) { 

        LogWrite_Host "     From : $BuildSourceFile " 
	    Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$Batch_DeploymentFolder -Force -recurse #-WhatIf
}

#----------------------------------------------------------------------------------------------------------------------
#
# Build Server

LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "Deploying To Build Server : $Build_DeploymentFolder "

foreach($BuildSourceFile in $BuildSourceFiles_Client) { 

        LogWrite_Host "     From : $BuildSourceFile " 
	    Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$Build_DeploymentFolder -Force -recurse #-WhatIf
}

#----------------------------------------------------------------------------------------------------------------------
#

#Application Server,  
#Connecting to share with the user

LogWrite_Host " " 
LogWrite_Host " "
LogWrite_Host "Deploying To Application Server : $App_DeploymentFolder "



foreach($BuildSourceFile in $BuildSourceFiles_Server) { 

        LogWrite_Host "     From : $BuildSourceFile " 
        Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$App_DeploymentFolder -Force -recurse #-WhatIf
        
        
}



LogWrite_Host " " 
LogWrite_Host " "
LogWrite_Host "End of Deploy" 
#----------------------------------------------------------------------------------------------------------------------
#
& net use * /d /yes | Out-Null
