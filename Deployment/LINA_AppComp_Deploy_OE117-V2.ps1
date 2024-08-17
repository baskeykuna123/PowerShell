
#       PARAM voorzien   "DIAP"
#       DCORP  rechstreeks =  develop branch
#       IAP    eerst via package folder = staging branch
#       $Environment = DCORP, ICORP, ECORP
#       $Name = Lina, pasMatrix, pasLinat, pasWorkflow, pasTalk

# 2021-10-28 : Luc Mercken : function LogWrite_Host


Param($Environment, $Name)


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


clear

if(!$Environment){$Environment="DCORP"}      #if no environment, then allways DCORP

if(!$Name){$Name="Lina"}                     #if no application name,  then allways Lina


LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "*****     Environment : $Environment           Name : $Name     ***** "
LogWrite_Host " "

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

switch ($Environment) {
                       "DCORP" { $Branch="Develop"   }
                       "ICORP" { $Branch="Staging"   } 
                       "ECORP" { $Branch="Emergency" }

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
$SourceFolder="E:\GitSources\" + $Branch + "\" + $Name

$CleanUpFolder="E:\GitSources\CleanUp\CleanUp_" + $Name + "_" + $Branch
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

#ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
#ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ



#--------------------------------------------------------------------------------------
#                                     Package Copy Function
#--------------------------------------------------------------------------------------


Function WritePackage {

    #Copy folders and files form the temporary CleanUp folder to the packages folder (Rxx main folder , Rxx version folder
    #
    LogWrite_Host " "
    LogWrite_Host "Copy to Package Folder : $PackageReleaseMainFolder "
    LogWrite_Host "Copy to Package Folder : $PackageReleaseVersionFolder "
    LogWrite_Host " "

    foreach($SourceFile in $PackageSourceFiles) { 

            LogWrite_Host "     From : $SourceFile "   

	        Copy-Item Filesystem::$SourceFile -Destination Filesystem::$PackageReleaseMainFolder -Force -recurse -ErrorAction Ignore

            Copy-Item Filesystem::$SourceFile -Destination Filesystem::$PackageReleaseVersionFolder -Force -recurse -ErrorAction Ignore
         
    }

    LogWrite_Host " "
    LogWrite_Host "End Copy To Package Folders "

}


# ==================================  END FUNCTION WritePackage  ==================================




#--------------------------------------------------------------------------------------
#           Getting ReleaseNumber and VersionNumber in case of a IAP deployment
#--------------------------------------------------------------------------------------

if($Environment -ieq "ICORP") {

    #
    
    $xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )


    $Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")
    $Release = $($node.Version).split('.')[0]
    $Version=$Node.Version

    LogWrite_Host "Release : $Release           Version : $Version "
    
    #
                                                                                      
    $PackageReleaseMainFolder="\\balgroupit.com\appl_data\BBE\Packages\Talk_OE117\R"+ $Release + "\" + $Name
    $PackageReleaseVersionFolder="\\balgroupit.com\appl_data\BBE\Packages\Talk_OE117\R" + $Release + "\" + $Version + "\" + $Name
                                                                                  

                                                                                      #TEST
    #$PackageReleaseMainFolder="\\balgroupit.com\appl_data\BBE\Packages\Talk_OE117_TEST\R"+ $Release + "\" + $Name
    #$PackageReleaseVersionFolder="\\balgroupit.com\appl_data\BBE\Packages\Talk_OE117_TEST\R" + $Release + "\" + $Version + "\" + $Name
                                                                                  #TEST

    #First check if package folders exist, if so delete these package folders and sub-folders
    #Create package folders
    #
    if (Test-Path $PackageReleaseMainFolder) {

        LogWrite_Host " "
        LogWrite_Host "Main Artefact Folder is present, will be removed : $PackageReleaseMainFolder"

        remove-item Filesystem::$PackageReleaseMainFolder -Force -recurse -ErrorAction Ignore
    }

    LogWrite_Host " "

    New-Item -ItemType Directory -Path $PackageReleaseMainFolder -ErrorAction Stop | Out-Null
    LogWrite_Host "Main Artefact Folder is created : $PackageReleaseMainFolder "



    if (Test-Path $PackageReleaseVersionFolder) {

        LogWrite_Host " "
        LogWrite_Host "Version Artefact Folder is present, will be removed : $PackageReleaseVersionFolder"

        remove-item Filesystem::$PackageReleaseVersionFolder -Force -recurse -ErrorAction Ignore
    }

    LogWrite_Host " "

    New-Item -ItemType Directory -Path $PackageReleaseVersionFolder -ErrorAction Stop | Out-Null
    LogWrite_Host "Version Artefact Folder is created : $PackageReleaseVersionFolder "


    start-sleep -seconds 2
    
}
#----------------------------------------------------------------------------------------------------------------------
#
#
$DeployFolders=@()
$ClientFolders=@()

switch ($Name) {

        "LINA"        {
                       $DeployFolders = "Control",
                                        "Form",
                                        "Image",
                                        "Include",
                                        "Lina",
                                        "Manager",
                                        "Model",
                                        "ServiceAdapter"
                      }

        "pasMatrix"   {
                       $DeployFolders = "Lina",
                                        "Manager",
                                        "ServiceAdapter",
                                        "ServiceInterface",
                                        "WebHandler"
                                        # "OpenEdge.BusinessLogic.pl"
                      }

        "pasWorkflow" {
                       $DeployFolders = "Batch",
                                        "Helper",
                                        "Lina",
                                        "Manager",
                                        "ServiceAdapter",
                                        "ServiceInterface",                
                                        "Workflow"
                                        # "OpenEdge.BusinessLogic.pl"
                      }

        "pasTalk"     {
                       $DeployFolders = "Lina",
                                        "Manager",
                                        "ServiceAdapter",
                                        "ServiceInterface",
                                        "Talk"
                                        # "OpenEdge.BusinessLogic.pl"
                            }

        "pasLinaT"    {
                       $DeployFolders = "Lina",
                                        #"LinaBackEnd",
                                        "Manager",
                                        "ServiceAdapter",
                                        "ServiceInterface" 
                                        # "OpenEdge.BusinessLogic.pl"
                      }


}
#----------------------------------------------------------------------------------------------------------------------


#
#
$NoBuildSourceFiles=@()
$NoBuildRemoveFiles=@()
$PackageSourceFiles=@()

foreach ($Folder in $DeployFolders) {
         $NoBuildSourceFiles+=($SourceFolder + "\" + $Folder)  
         $NoBuildRemoveFiles+=($CleanUpFolder + "\" + $Folder) 
         $PackageSourceFiles+=($CleanUpFolder + "\" + $Folder)     
}



#----------------------------------------------------------------------------------------------------------------------

#remove all the existing folders and items in the temporary CleanUp folder
#
if (Test-Path $CleanUpFolder) {

    LogWrite_Host
    LogWrite_Host "CleanUp Folder is present, will be removed : $CleanUpFolder"

    remove-item Filesystem::$CleanUpFolder -Force -recurse -ErrorAction Ignore
}

New-Item -ItemType Directory -Path $CleanUpFolder -ErrorAction Stop | Out-Null
LogWrite_Host "CleanUp Folder is created : $CleanUpFolder "

start-sleep -seconds 2

#----------------------------------------------------------------------------------------------------------------------

#copy all files extracted from GIT to the temporary CleanUp folder
#

LogWrite_Host "Copy Start To Folder  :  $CleanUpFolder " 
LogWrite_Host " "


foreach($SourceFile in $NoBuildSourceFiles) { 

        LogWrite_Host "     From : $SourceFile   "
	    Copy-Item Filesystem::$SourceFile -Destination Filesystem::$CleanUpFolder -Force -recurse -ErrorAction Ignore

         
}


#----------------------------------------------------------------------------------------------------------------------
#
LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "Delete Files Start " 
LogWrite_Host " "

#files not included in build.pl ,  remove .P, .W, .Cls or .I code,   and R-code stays in place in the temporary CleanUp folder
#
foreach ($Remove_File in $NoBuildRemoveFiles){

         if (Test-Path $Remove_File ) {
             
             LogWrite_Host "     NoBuild  :  $Remove_File "

             get-childitem -path $Remove_File * -include *.p, *.w, *.cls, *.i, *.log, *.scc, thumbs.db, *.xe, Connection.xml -recurse | remove-item -force -ErrorAction Ignore
         }
}



LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "End Delete Files "

#----------------------------------------------------------------------------------------------------------------------

# ICORP : putting all the stuff to the packages folder for the next step, deployment tot servers and citrix
#
if($Environment -eq "ICORP") { WritePackage }




#----------------------------------------------------------------------------------------------------------------------
 