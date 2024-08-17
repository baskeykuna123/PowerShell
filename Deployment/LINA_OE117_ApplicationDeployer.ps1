# 2020-01-16 : Luc Mercken 
# Lina  TalkFrontend component :  only used in citrix environment and local development server
# 2020-02-12 : Luc Mercken : added 003_client
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-12-17 : Luc Mercken : TalkFrontEnd is changed in Lina,  more and new directories,  source of the code  is also changed
# 2020-12-28 : Luc Mercken : changes to OE117 Version and new environment of servers
# 2021-05-04 : Luc Mercken : Dcorp artefacts on build-server
# 2021-06-02 : Luc Mercken : also deploy to the build-server local client sources (find : Build server)
#

#                                               en  WHATIF   !!!!!!
#
Param($Environment)


Clear
write-host "INPUT PARAM environment : " $Environment


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
Write-Host "Release : " $Release 


if ($Environment -eq "DCORP") { 
       $PackageFolder="E:\GitSources\CleanUp\CleanUp_Lina_Develop" 
}
else {
      $PackageFolder="\\balgroupit.com\appl_data\BBE\Packages\Talk_OE117\R" + $release + "\Lina"
}


# Check if package folder exist
#  

if (Test-Path $PackageFolder) {
    write-host "  Package folder is present"
}
else {
      
      write-host "  Package folder is NOT PRESENT"
      stop
}


write-host "Package Version Folder : " $PackageFolder
write-host


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

#Build Server
$Build_DeploymentFolder=[string]::Format("\\svw-be-tlkbd002.balgroupit.com\E$\Client_Sources\{0}\Lina",$Environment)

#Citrix Client TransferLocations
$Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-RZ3\Lina",$global:TransferShareRoot,$Environment)

if ($Environment -ieq "PCORP") {
    $Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_DWP\TALK\{1}-Current\Lina",$global:TransferShareRoot,$Environment)
}


write-host "Application Server      :  " $App_DeploymentFolder
write-host "Batch Server            :  " $Batch_DeploymentFolder
write-host "Build Server            :  " $Build_DeploymentFolder
write-host "Citrix                  :  " $Citrix_DeploymentFolder
write-host
write-host



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

$TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
write-host "Delete start     " $TimeStamp

foreach ($Remove_File in $RemoveFiles_Citrix){
         write-host "     Deleting Citrix : " $Remove_File
         remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-whatif
}


write-host
foreach ($Remove_File in $RemoveFiles_BatchServer){
         write-host "     Deleting Batch : " $Remove_File
         remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-WhatIf
}


write-host
foreach ($Remove_File in $RemoveFiles_BuildServer){
         write-host "     Deleting Build : " $Remove_File
         remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-WhatIf
}


write-host
foreach ($Remove_File in $RemoveFiles_ApplicationServer){
         write-host "     Deleting App : " $Remove_File 
         remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-WhatIf
}


$TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
write-host "Delete stop     " $TimeStamp

start-sleep -seconds 10

#----------------------------------------------------------------------------------------------------------------------
# next deployment source folders and attributes

#Citrix
# Connecting to share with the user
$TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
write-host
write-host
Write-Host 	 "   Deploying To Citrix : " $Citrix_DeploymentFolder "          " $TimeStamp


foreach($BuildSourceFile in $BuildSourceFiles_Client) { 

        write-host "     From : " $BuildSourceFile 
	    Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$Citrix_DeploymentFolder -Force -recurse #-WhatIf
}


#----------------------------------------------------------------------------------------------------------------------
#
# Batch Server

$TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
Write-Host 	 "   Deploying To Batch Server : " $Batch_DeploymentFolder "          " $TimeStamp
foreach($BuildSourceFile in $BuildSourceFiles_Client) { 

        write-host "     From : " $BuildSourceFile 
	    Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$Batch_DeploymentFolder -Force -recurse #-WhatIf
}

#----------------------------------------------------------------------------------------------------------------------
#
# Build Server

$TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
Write-Host 	 "   Deploying To Build Server : " $Build_DeploymentFolder "          " $TimeStamp
foreach($BuildSourceFile in $BuildSourceFiles_Client) { 

        write-host "     From : " $BuildSourceFile 
	    Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$Build_DeploymentFolder -Force -recurse #-WhatIf
}

#----------------------------------------------------------------------------------------------------------------------
#

#Application Server,  
#Connecting to share with the user
$TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
write-host 
write-host
Write-Host 	 "   Deploying To Application Server : " $App_DeploymentFolder "          " $TimeStamp



foreach($BuildSourceFile in $BuildSourceFiles_Server) { 

        write-host "     From : " $BuildSourceFile 
        Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$App_DeploymentFolder -Force -recurse #-WhatIf
        
        
}


$TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
write-host 
write-host
Write-Host 	 "   End Deploying           " $TimeStamp
#----------------------------------------------------------------------------------------------------------------------
#
& net use * /d /yes | Out-Null
