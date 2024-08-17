# 2020-02-03 : Luc Mercken 
# 2020-03-10 : just one scripet for the pasOE Lina
#              we test which pasOe is required (input parameter)  
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-12-16 : Luc Mercken : added pasLinaT
# 2020-12-28 : changes to OE117 version and new server environment
# 2021-05-04 : Luc Mercken : Dcorp artefacts on build-server
#                            ALL = all pacifics components instead of each apart (used for Dcorp)
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

Clear



if(!$Environment){ $Environment="DCORP" }

if(!$Name){ $Name="pasMatrix" }


# --------------------------------------------------------------------------------------------------------- #
#                        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#                                      SOURCES are located on packages folder I-A-P
#                                                             build server    D 
#                        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#

# --------------------------------------------------------------------------------------------------------- #
#
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

write-host " "
write-host " "
Write-Host "Release     : " $Release  "    Version : " $Version
write-host "Environment : " $Environment "    pasName : " $Name
write-host " "
write-host " "

#======================================================================================================================

function DoTheDeploy {

        param ($Name)

        if ($Environment -eq "DCORP") { 
              $PackageFolder="E:\GitSources\CleanUp\CleanUp_" + $Name + "_Develop"
        }
        else {
              $PackageFolder="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117\R" + $release + "\" + $Name      
        }

        #----------------------------------------------------------------------------------------------------------------------
        # Check if package folder exist
        #  

        if (Test-Path $PackageFolder) {
            write-host "Package folder is present"
        }
        else {
              if ($Environment -ieq "DCORP") {
                  New-Item -ItemType Directory -Path $PackageFolder -ErrorAction Stop | Out-Null
                  write-host "  Package folder is created"
                  start-sleep -seconds 5
              }
              else {
                    write-host "  Package folder is NOT PRESENT"
                    exit 1
              }
        }


        write-host "   > > > : " $PackageFolder
        write-host


        #----------------------------------------------------------------------------------------------------------------------
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



    write-host "Application Server     :  " $001_DeploymentFolder
    write-host
    write-host

    # Connecting to share with the user
    & net use $001_DeploymentFolder /user:$($userid) $($pwd)

    # first remove existing destination folders and attributes
    #---------------------------------------------------------

    write-host $001_DeploymentFolder

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    write-host "Delete start     " $TimeStamp

    $RemoveFiles_Server_001=@()
    foreach ($Folder in $Folders_Server) {
            write-host "FOLDER :" $Folder
            $RemoveFiles_Server_001+= ($001_DeploymentFolder + "\" + $Folder )  
                   
    }

    
    foreach ($Remove_File in $RemoveFiles_Server_001) {
             write-host "     Deleting : " $Remove_File
             remove-item Filesystem::$Remove_File -Force -recurse -ErrorAction Ignore #-WhatIf
    }

    write-host
    write-host
    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    write-host "Delete stop     " $TimeStamp
    write-host

    start-sleep -seconds 5

    
    # next deployment source folders and attributes
    #----------------------------------------------
    write-host 
    write-host
    Write-Host 	 "Deploying To Servers : " $001_DeploymentFolder 

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    write-host "Copy start     " $TimeStamp

    foreach($BuildSourceFile in $BuildSourceFiles_Server) { 
            write-host "From " $BuildSourceFile 
            Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$001_DeploymentFolder -Force -recurse #-WhatIf
                
    }

    write-host
    write-host
    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    write-host "Copy stop     " $TimeStamp

    & net use * /d /yes | Out-Null

} #function

#======================================================================================================================


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



# =================================================================================================================================
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




#& net use * /d /yes | Out-Null



# =================================================================================================================================
#

    

