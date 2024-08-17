# 2020-02-03 : Luc Mercken 
# 2020-03-10 : just one scripet for the pasOE Lina
#              we test which pasOe is required (input parameter)  
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-12-16 : Luc Mercken : added pasLinaT
# 2020-12-28 : changes to OE117 version and new server environment
# 2021-05-04 : Luc Mercken : Dcorp artefacts on build-server
#                            ALL = all pacifics components instead of each apart (used for Dcorp)
# 2021-09-27 : Luc Mercken : adding Ecorp
# 2021-10-27 : Luc Mercken : function LogWrite_Host
#
#   
# copying artefacts from packages folder (I-A-P)
# if environment is DCORP, then copy to packages folder !
#
# extras for pasWorkflow in folder Openedge\Batch : \Batch\BatchErrorLog.txt
#
#
# pasMatrix, pasMatrix, pasWorkflow, pasLinaT
# each pasOE has its own folders to deploy, see "pasOE folders"



#                                              en  WHATIF   !!!!!!
Param($Environment, $Name)


#------------------------------------------------------------------------------------------------------------
#                                      Functions
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------
#     Write-Host_with_TimeStamp Function
#------------------------------------------------------------------------------------------------------------
Function LogWrite_Host {

    param ($LogString)

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    Write-Host $TimeStamp "     " $LogString
}


#------------------------------------------------------------------------------------------------------------


Clear



if(!$Environment){ $Environment="DCORP" }

if(!$Name){ $Name="pasMatrix" }


# --------------------------------------------------------------------------------------------------------- #
#                        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#                                      SOURCES are located on packages folder I-A-P
#                                                             build server    D - E
#                        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#

# --------------------------------------------------------------------------------------------------------- #
#
#Loading All modules

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


#------------------------------------------------------------------------------------------------------------
# Getting ReleaseNumber (and VersionNumber,  not needed at this moment )


$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )


$Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")
$Release = $($node.Version).split('.')[0]
$Version=$Node.Version

LogWrite_Host " "
LogWrite_Host " "

if ($Environment -ne "DCORP" -and $Environment -ne "ECORP") {
    LogWrite_Host "Release     : $Release         Version : $Version "
}

LogWrite_Host "Environment : $Environment     pasName : $Name "
LogWrite_Host " "
LogWrite_Host " "

#============================================================================================================

function DoTheDeploy {

        param ($Name)

        LogWrite_Host "Pacific Name : $Name "


        #Icorp,  Acorp,  Pcorp
        $PackageFolder="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117\R" + $release + "\" + $Name

        #Dcorp
        if ($Environment -eq "DCORP") { 
              $PackageFolder="E:\GitSources\CleanUp\CleanUp_" + $Name + "_Develop"
        }

        #Ecorp
        if ($Environment -eq "ECORP") { 
              $PackageFolder="E:\GitSources\CleanUp\CleanUp_" + $Name + "_Emergency"
        }


        #----------------------------------------------------------------------------------------------------
        # Check if package folder exist
        #  

        if (Test-Path $PackageFolder) {
            LogWrite_Host "Package folder is present : $PackageFolder "
        }
        else {
              if ($Environment -ieq "DCORP") {
                  New-Item -ItemType Directory -Path $PackageFolder -ErrorAction Stop | Out-Null

                  LogWrite_Host "  Package folder is created : $PackageFolder "
                  start-sleep -seconds 5
              }
              else {
                    LogWrite_Host "  Package folder is NOT PRESENT : $PackageFolder "
                    exit 1
              }
        }




        #----------------------------------------------------------------------------------------------------
        # pasOE folders
        #
        $Folders_Server=@()

        switch($Name){

               "pasMatrix"   {
                              $Folders_Server=("Lina"),
                                              ("Manager"),
                                              ("ServiceAdapter"),
                                              ("ServiceInterface"),
                                              ("WebHandler")
                                              # ("OpenEdge.BusinessLogic.pl")
                             }

               "pasTalk"     {
                              $Folders_Server=("Lina"),
                                              ("Manager"),
                                              ("ServiceAdapter"),
                                              ("ServiceInterface"),
                                              ("Talk")
                                              # ("OpenEdge.BusinessLogic.pl")
                             }
                      
               "pasWorkflow" {
                              $Folders_Server=("Batch"),
                                              ("Helper"),
                                              ("Lina"),
                                              ("Manager"),
                                              ("ServiceAdapter"),
                                              ("ServiceInterface"),                
                                              ("Workflow")
                                              # ("OpenEdge.BusinessLogic.pl")
                             }
               "pasLinaT"    {
                              $Folders_Server=("Lina"),
                                              #("LinaBackEnd"),
                                              ("Manager"),
                                              ("ServiceAdapter"),
                                              ("ServiceInterface") 
                                              # ("OpenEdge.BusinessLogic.pl")
               }                 
        }


        $BuildSourceFiles_Server=@()
        foreach ($Folder in $Folders_Server) {
                 $BuildSourceFiles_Server+=($PackageFolder + "\" + $Folder)        
        }

    #
    #Server Locations
    $001_DeploymentFolder=[string]::Format("\\Life-{0}-Talk-App-BE\E$\OpenEdge\WRK\117\{1}\OpenEdge",$Environment, $Name)


    LogWrite_Host "Application Server     :  $001_DeploymentFolder "
    LogWrite_Host " "
    LogWrite_Host " "


    #
    # Connecting to share with the user
    & net use $001_DeploymentFolder /user:$($userid) $($pwd)

    #
    # first remove existing destination folders and attributes
    #---------------------------------------------------------

    
    LogWrite_Host "Start Delete Current " 

    $RemoveFiles_Server_001=@()
    foreach ($Folder in $Folders_Server) {

            LogWrite_Host "     FOLDER :  $Folder "
            $RemoveFiles_Server_001+= ($001_DeploymentFolder + "\" + $Folder )  
                   
    }

    
    foreach ($Remove_File in $RemoveFiles_Server_001) {

             LogWrite_Host "        Deleting : $Remove_File " 
             remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-WhatIf
    }

    LogWrite_Host "End Delete Current " 

    start-sleep -seconds 5

    
    # next deployment source folders and attributes
    #----------------------------------------------
    LogWrite_Host " " 
    LogWrite_Host " "
    LogWrite_Host "Deploying To Server : $001_DeploymentFolder "

    LogWrite_Host "Start Copy " 

    foreach($BuildSourceFile in $BuildSourceFiles_Server) {
     
            LogWrite_Host "     From : $BuildSourceFile " 
            Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$001_DeploymentFolder -Force -recurse #-WhatIf
                
    }

    LogWrite_Host "End Copy "
    LogWrite_Host " "
    LogWrite_Host " "
     

    & net use * /d /yes | Out-Null

} #function

#============================================================================================================


# --------------------------------------------------------------------------------------------------------- #
#


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



# ===========================================================================================================
#


## Connecting to share with the user
#& net use $001_DeploymentFolder /user:$($userid) $($pwd)
    

if ($Environment -eq "DCORP" -or $Name -eq "ALL") {

    $PASoes = "pasTalk",
              "pasLinaT",
              "pasMatrix",
              "pasWorkflow"

    foreach ($Name in $PASoes) {
               
        DoTheDeploy $Name
    }
}
else {
      DoTheDeploy $Name
}



# ===========================================================================================================
#

    

