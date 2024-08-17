# 2020-02-06 : Luc Mercken
# 2020-02-25 :  1 script executing 'prepare' and 'executed'
# 2020-03-04 :  additional input parameter : BAckOffice or Front
#               extra Schema_prep function for front,  several test Back or front for variables
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-08-13 : Luc Mercken : F:\Database  as head-folder instead of F:\TalkDb
# 2021-02-16 : Luc Mercken : package folders  _OE117 
# 2021-04-27 : Luc Mercken : Back/Front are on one server,  so no longer different ways
# 2021-05-06 : Luc Mercken : Talk database has in the input to be WsTalk !
# 2021-05-19 : Luc Mercken : adding build-corp,  first update the B&I database on build-server, followed by the 'release-prod' compil
#                            instead of compiling towards the Icorp databases
# 2021-05-26 : Luc Mercken : EMERG en Ecorp added,  Emergency pipe-line
# 
# loading data definitions into the databases OE
# 2 functions :
#   - Prepare  : getting the df files situated in Corp start folder (e.g. for Icorp will start from Dcorp folder)
#                making of an input file  ( Input_DB_DFs.txt )
#                deleting existing Db-Schema folder on Db-server
#                copying template scripts to Db-Schema folder (source : packages\Scripts\Database\Talk_OE117)
#                copy df files and input file to the db-server (e.g. Icorp)
#                save original df files in a Save folder, save input file and renaming it (time-stamp and xCorp-name)
#
#                Database names are hard-coded in this script
#                Database foldernames (xCorp) are hardcoded in this script
#
#   - Executed : retrieving the logging back from the db server
#                check logging for errors
#                df file which did not returned error are moved to the current updated XCorp folder(e.g. from Dcorp to Icorp)
#                if df returned with an error,  df file stays in the folder,  step failed !
#
# Loading history :
#         Updating Icorp : source = Dcorp folder,  if succeeded move to Icorp folder (actual state), copy to the save folder
#         Updating Acorp : source = Icorp folder,  if succeeded move to Acorp folder
#         Updating Pcorp : source = Acorp folder,  if succeeded move to Pcorp folder  
#         always a save of the input file , title modified with time-stamp and environment-name
#
# Folders : Packages\Talk\Rxx\Db-Schema\
#           Dcorp : copying the delivered Df-files manually
#           ICorp, Acorp, Pcorp : contains the df files which are current updated in the environment
#           Save : saves of the Df-files (from Dcorp) and input-files with time-stamp_Environment (date of execution in that environment)  
#
# Additional Folder : Packages\Scripts\Database\Talk
#            The executable bat-file (DF_Laden.bat)
#            input file : Corp_Db_Names.csv,  contains the display-name of the databases as published in OE-ManagerConsole
#                                             Column 1 = Db-Name, 2 = Icorp disp-name, 3 = Acorp disp-name, 4 = Pcorp disp-name
#            3 OE-scripts :  DFs_naar_Talk.r,  DFFile_Load.r,  Disconnect.r
#                            DFs_naar_Talk.r is started by the bat-file,  creates extra bat-files to Stop/Start databases 
#                                            does the connect action database in single-mode (offline)
#                                            call's   DFFile_Load.r  actually executing the update per database (creation individual log file per Df)
#                                            call's    Disconnect.r  disconnect the database
#                                            Generates the overall log-file which is included in the Jenkins ConsoleOutput
#
# Server Folder : F:\TalkDb\Db-Schema
# Are not saved : the individual logfiles and general log-file created on the db server,  general log-file is included in the Jenkins Console Output
#
#
# $Action      : prepare,  executed
# $Environment : Icorp, Acorp, Pcorp, 
#                BUILD is situated on the build-server,  normal deployment route
#                EMERG is situated on the build-server,  emergency folders
#                ECORP is svw-be-tlkae001 server
# $BackFront   : Back,  Front  > no longer in use
#
#


Param($Environment, $Action)
#Param($Environment, $Action, $BackFront)

Clear


if(!$Environment){
    $Environment="BUILD"
}

if(!$Action){
   $Action="executed"
}


# --------------------------------------------------------------------------------------------------------------------
# 
#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#
#----------------------------------------------------------------------------------------------------------------------
# Getting ReleaseNumber and VersionNumber (Versionnumber not needed in this script,  just used as identifying
#


$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )
$Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")


$Release = $($node.Version).split('.')[0]
$Version=$Node.Version

Write-Host "Release : " $Release "          Version : " $Version
write-host " "


# --------------------------------------------------------------------------------------------------------------------
# General declarations

$DatabaseMainFolder="F:\Database\"
$DatabaseSchemaFolder="F:\Database\DB-Schema\"
$InputFileName="Input_DB_DFs.txt"
$ProgramFolder="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Database\Talk_OE117" 
$ErrorExit=$false

if ($Environment -eq "EMERG") {
    $DatabaseMainFolder="F:\E_Database\"
    $DatabaseSchemaFolder="F:\E_Database\DB-Schema\"
}

# --------------------------------------------------------------------------------------------------------------------
# 

# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !

<#
$SaveEnvironment=$Environment

if ($Environment -eq "ECORP") {    
    $Environment = "ACORP" 
}


$serval=$Environment[0]

#retrieve the User and password from the DB 
#$Userid=get-Credentials -Environment $Environment -ParameterName  "TALKServerUser"
#$Pwd=get-Credentials -Environment $Environment -ParameterName  "TALKServerPassword"

$Environment=$SaveEnvironment
#>

# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !

switch($Environment){

	   "ICORP" {
				$serval="i"
				$userid="balgroupit\L001235"
				$pwd="b5VfDZRN" #| ConvertTo-SecureString -asPlainText -Force
	   }

	   "ACORP" {
				$serval="a"
				$userid="balgroupit\L001097"
				$pwd="Basler09" #| ConvertTo-SecureString -asPlainText -Force
	   }

	   "PCORP" {
				$serval="p"
				$userid="balgroupit\L001129"
				$pwd="PMerc_11" #| ConvertTo-SecureString -asPlainText -Force
	   }

	   "ECORP" {
				$serval="e"
				$userid="balgroupit\L001097"
				$pwd="Basler09" #| ConvertTo-SecureString -asPlainText -Force
	   }

}

# --------------------------------------------------------------------------------------------------------------------
#
#Deployment folder on Database Server 001,  except "BUILD" and "EMERG" on the buildserver


$DeploymentFolder=[string]::Format("\\svw-be-tlka{0}001.balgroupit.com\F$\DataBase\DB-Schema",$serval)

if ($Environment -eq "BUILD") {
    $DeploymentFolder="F:\Database\Db-Schema"
}

if ($Environment -eq "EMERG") {
    $DeploymentFolder="F:\E_Database\Db-Schema"
}

# ====================================================================================================================
# 
#                                                   Prepare function
# ====================================================================================================================

Function Schema_Prep {

    $SaveFolder=$PackagesFolder + "Save"

    switch($Environment){

           "EMERG" {
                    $InputFolder= "F:\E_Database\Inc_Schema\Build"

                    if (test-path $InputFolder) {
                        write-host "    Input Db-Schema Folder is present  : " $InputFolder    
                    }
                    else {
                          write-host "    Input Db-Schema Folder is NOT present : " $InputFolder
                          New-Item -ItemType Directory -Path $InputFolder -ErrorAction Stop | Out-Null
                          write-host ">>  Input Db-Schema Folder is created  : " $InputFolder 
                    }

           }

           "ECORP" {
                    $InputFolder= "F:\E_Database\Inc_Schema\ECORP"

                    if (test-path $InputFolder) {
                        write-host "    Input Db-Schema Folder is present  : " $InputFolder    
                    }
                    else {
                          write-host "    Input Db-Schema Folder is NOT present : " $InputFolder
                          New-Item -ItemType Directory -Path $InputFolder -ErrorAction Stop | Out-Null
                          write-host ">>  Input Db-Schema Folder is created  : " $InputFolder 
                    }

           }

           "BUILD" {
                    $InputFolder= $PackagesFolder + "Build"

                    if (test-path $InputFolder) {
                        write-host "    Input Db-Schema Folder is present  : " $InputFolder    
                    }
                    else {
                          write-host "    Input Db-Schema Folder is NOT present : " $InputFolder
                          New-Item -ItemType Directory -Path $InputFolder -ErrorAction Stop | Out-Null
                          write-host ">>  Input Db-Schema Folder is created  : " $InputFolder 
                    }

                   if (test-path $SaveFolder) {
                       write-host "    Save Db-Schema Folder is present   : " $SaveFolder    
                    }
                    else {
                          write-host "    Save Db-Schema Folder is NOT present : " $SaveFolder
                          New-Item -ItemType Directory -Path $SaveFolder -ErrorAction Stop | Out-Null
                          write-host ">>  Save Db-Schema Folder is created : " $SaveFolder
                    }


           }

           "ICORP" {
                    $InputFolder= $PackagesFolder + "Dcorp" 
                                   
                    if (test-path $InputFolder) {
                        write-host "    Input Db-Schema Folder is present  : " $InputFolder    
                    }
                    else {
                          write-host "    Input Db-Schema Folder is NOT present : " $InputFolder
                          New-Item -ItemType Directory -Path $InputFolder -ErrorAction Stop | Out-Null
                          write-host ">>  Input Db-Schema Folder is created  : " $InputFolder 
                    }

  
                   if (test-path $SaveFolder) {
                       write-host "    Save Db-Schema Folder is present   : " $SaveFolder    
                    }
                    else {
                          write-host "    Save Db-Schema Folder is NOT present : " $SaveFolder
                          New-Item -ItemType Directory -Path $SaveFolder -ErrorAction Stop | Out-Null
                          write-host ">>  Save Db-Schema Folder is created : " $SaveFolder
                    }

           }

           "ACORP" {
                    $InputFolder= $PackagesFolder + "Icorp" 
                    if (test-path $InputFolder) {
                        write-host "    Input Db-Schema Folder is present  : " $InputFolder    
                    }
                    else {
                          write-host "    Input Db-Schema Folder is NOT present : " $InputFolder
                          New-Item -ItemType Directory -Path $InputFolder -ErrorAction Stop | Out-Null
                          write-host ">>  Input Db-Schema Folder is created  : " $InputFolder 

                    }

           }

           "PCORP" {
                    $InputFolder= $PackagesFolder + "Acorp" 
                    if (test-path $InputFolder) {
                        write-host "    Input Db-Schema Folder is present  : " $InputFolder    
                    }
                    else {
                          write-host "    Input Db-Schema Folder is NOT present : " $InputFolder
                          New-Item -ItemType Directory -Path $InputFolder -ErrorAction Stop | Out-Null
                          write-host ">>  Input Db-Schema Folder is created  : " $InputFolder 

                    }

           }


    }

    # --------------------------------------------------------------------------------------------------------------------
    # 
    $InputFile=$InputFolder + "\" + $InputFileName

    # --------------------------------------------------------------------------------------------------------------------
    # 
    if (test-path $DeploymentFolder) {
        write-host ">   Server Db-Schema Folder is present : " $DeploymentFolder  
        write-host ">>  Folder will be cleared !"
        get-childitem -path $DeploymentFolder -include *.* -recurse -ErrorAction Ignore | remove-item -force -ErrorAction Ignore
    }
    else {
          New-Item -ItemType Directory -Path $DeploymentFolder -ErrorAction Stop | Out-Null
          write-host ">   Server Db-Schema Folder is created : " $DeploymentFolder
    }


    # --------------------------------------------------------------------------------------------------------------------
    # 
    if ($Environment -ne "BUILD" -and $Environment -ne "EMERG") {
        & net use $DeploymentFolder /user:$($userid) $($pwd)
    }

    # --------------------------------------------------------------------------------------------------------------------
    # copy of the bat-file and OE scripts
    Copy-Item Filesystem::$ProgramFolder -Destination Filesystem::$DeploymentFolder -Force -recurse 


    # --------------------------------------------------------------------------------------------------------------------
    # 
    if (test-path $InputFile) {
        write-host ">>  Old input file is present, will be cleared : " $InputFile  
        remove-item -path $InputFile  -force -recurse -ErrorAction Ignore
    }
    write-host " "
    write-host " "

    # --------------------------------------------------------------------------------------------------------------------
    # 
    $PackageFileFolder=@()

    get-childitem -path $InputFolder  -File | sort-object | foreach-object {
                                                                            write-host "File : " $_.Name
                                                                            $PackageFileFolder+=$_.Name
                                                            }

    # foreach beginning
    foreach ($DbFile in $PackageFileFolder) {
                  
             # Databases
             $Talkolap = $Dbfile -match "talkolap"
             $Talkcore = $Dbfile -match "talkcore"
             $Mercator = $DbFile -match "Mercator"
             $Matrix   = $DbFile -match "matrix"
             $LinaT    = $DbFile -match "LinaT"
             $Workflow = $DbFile -match "Workflow"
             $Talkmig  = $DbFile -match "Talkmig"
             $Stddb    = $DbFile -match "Stddb"
             $Wldb     = $DbFile -match "Wldb"
             $TalkDb   = $Dbfile -match "WsTalk"


             #
             # 
             if ($talkcore -contains $true) {
             
                 if ($Environment -eq "BUILD" -or $Environment -eq "EMERG") {
                       $Line= $DatabaseMainFolder + "DbTalkcore\Talkcore.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                       add-content $InputFile -value $Line

                 }
                 else {                                          
                       $Line= $DatabaseMainFolder + "DbTalkcore_T\Talkcore.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                       add-content $InputFile -value $Line

                       $Line= $DatabaseMainFolder + "DbTalkcore_M\Talkcore.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                       add-content $InputFile -value $Line 
                 }                                  
             }
             
             #
             if ($Mercator -contains $true) {  
                 $Line= $DatabaseMainFolder + "DbMercator\Mercator.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                 add-content $InputFile -value $Line  
             } 

             #
             if ($Talkmig -contains $true) { 
                 $Line= $DatabaseMainFolder + "DbTalkmig\Talkmig.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                 add-content $InputFile -value $Line
             } 

             #
             if ($Stddb -contains $true) { 
                 $Line= $DatabaseMainFolder + "DbStddb\Stddb.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                 add-content $InputFile -value $Line
             } 

             #
             if ($Wldb -contains $true) { 
                 $Line= $DatabaseMainFolder + "DbWldb\Wldb.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                 add-content $InputFile -value $Line
             } 

             #
             if ($talkolap -contains $true) { 
                 $Line = $DatabaseMainFolder + "DbTalkolap\TalkOlap.db;" + $DatabaseSchemaFolder + $DbFile + ";" 
                 add-content $InputFile -value $Line
             }         


             if ($Matrix -contains $true) {                     
                 $Line = $DatabaseMainFolder + "DbMatrix\matrix.db;" + $DatabaseSchemaFolder + $DbFile + ";" 
                 add-content $InputFile -value $Line
             }         

             if ($LinaT -contains $true) {                     
                 $Line = $DatabaseMainFolder + "DbLinaT\LinaT.db;" + $DatabaseSchemaFolder + $DbFile + ";" 
                 add-content $InputFile -value $Line
             }         
 
             if ($Workflow -contains $true) {                    
                 $Line = $DatabaseMainFolder + "DbWorkflow\workflow.db;" + $DatabaseSchemaFolder + $DbFile + ";"     
                 add-content $InputFile -value $Line
             }         

             if ($talkDb -contains $true) {

                 if ($Environment -eq "BUILD" -or $Environment -eq "EMERG") {
                       $Line= $DatabaseMainFolder + "DbTalk\Talk.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                       add-content $InputFile -value $Line

                 }
                 else {  
                       $Line= $DatabaseMainFolder + "DbTalk_T\Talk.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                       add-content $InputFile -value $Line

                       $Line= $DatabaseMainFolder + "DbTalk_M\Talk.db;" + $DatabaseSchemaFolder + $DbFile + ";"
                       add-content $InputFile -value $Line  
                 }                                
             }      
     
                         
              
             # copy the df-file to the database-server
             $CopyDfFile = $InputFolder + "\" + $DbFile

             write-host "Copy Df_File : " $CopyDfFile

             copy-Item Filesystem::$CopyDfFile -Destination Filesystem::$DeploymentFolder -Force 
             if ($Environment -eq "ICORP") {
                 copy-Item Filesystem::$CopyDfFile -Destination Filesystem::$SaveFolder -Force 
             }

    }
    # foreach ending

    
    # --------------------------------------------------------------------------------------------------------------------
    # in case there are no new schema files, input file does noet excist,  so we create a empty file
    write-host " "
    write-host " "

    if (test-path $InputFile) {
        add-content $InputFile -value $Environment
        write-host ">   Input file is present : " $InputFile      
    }
    else {
          New-Item $Inputfile -ItemType File -Force | Out-Null
          write-host ">>  Empty Input File is created : " $Inputfile 
    }


    # --------------------------------------------------------------------------------------------------------------------
    # 
    write-host "    Copy Input file : " $InputFile

    copy-Item Filesystem::$InputFile -Destination Filesystem::$DeploymentFolder -Force 
    copy-Item Filesystem::$InputFile -Destination Filesystem::$SaveFolder -Force 
    

    write-host " "
    write-host " "


    # --------------------------------------------------------------------------------------------------------------------
    # rename input file in save-folder
    $SaveFile=$SaveFolder + "\" + $InputFileName

    $KeyName=([System.IO.Path]::GetFileNameWithoutExtension($SaveFile))

    $timestamp=get-date -Format "yyyyMMdd_HHmmss"
    $RenameFile=$KeyName + "_" + $TimeStamp + "_" + $Environment + ".txt"
    rename-item Filesystem::$SaveFile -NewName $RenameFile


    # --------------------------------------------------------------------------------------------------------------------
    # 
    #& net use * /d /yes | Out-Null


} # end of Function Schema_Prep



# ====================================================================================================================
# 
#                                                   Executed function
# ====================================================================================================================

Function Schema_Exec {

    switch($Environment){

           "EMERG" {
                    $InputFolder= "F:\E_Database\Inc_Schema\Build" 
                    $NextFolder="F:\E_Database\Inc_Schema\Ecorp"
               
                    if (test-path $InputFolder) {
                        write-host ">   Input Db-Schema Folder is present : " $InputFolder    
                    }
                    else {
                          write-host ">>  Input Db-Schema Folder is NOT present : " $InputFolder
                          write-host "!!!     THERE IS SOMETHING WRONG     !!!" 
                          exit 1
                    }

  
                    if (test-path $NextFolder) {
                        write-host ">   Dcorp Db-Schema Folder is present : " $NextFolder    
                    }
                    else {
                          write-host ">>  Dcorp Db-Schema Folder is NOT present : " $NextFolder
                          New-Item -ItemType Directory -Path $NextFolder -ErrorAction Stop | Out-Null
                          write-host ">   Ecorp Db-Schema Folder is created : " $NextFolder
                    }

           }

           "ECORP" {
                    $InputFolder= "F:\E_Database\Inc_Schema\Ecorp" 
                    $NextFolder="F:\E_Database\Inc_Schema\Pcorp"
               
                    if (test-path $InputFolder) {
                        write-host ">   Input Db-Schema Folder is present : " $InputFolder    
                    }
                    else {
                          write-host ">>  Input Db-Schema Folder is NOT present : " $InputFolder
                          write-host "!!!     THERE IS SOMETHING WRONG     !!!" 
                          exit 1
                    }

  
                    if (test-path $NextFolder) {
                        write-host ">   Pcorp Db-Schema Folder is present : " $NextFolder    
                    }
                    else {
                          write-host ">>  Pcorp Db-Schema Folder is NOT present : " $NextFolder
                          New-Item -ItemType Directory -Path $NextFolder -ErrorAction Stop | Out-Null
                          write-host ">   Pcorp Db-Schema Folder is created : " $NextFolder
                    }

           }


           "BUILD" {
                    $InputFolder= $PackagesFolder + "Build" 
                    $NextFolder=$PackagesFolder + "Dcorp"
               
                    if (test-path $InputFolder) {
                        write-host ">   Input Db-Schema Folder is present : " $InputFolder    
                    }
                    else {
                          write-host ">>  Input Db-Schema Folder is NOT present : " $InputFolder
                          write-host "!!!     THERE IS SOMETHING WRONG     !!!" 
                          exit 1
                    }

  
                    if (test-path $NextFolder) {
                        write-host ">   Dcorp Db-Schema Folder is present : " $NextFolder    
                    }
                    else {
                          write-host ">>  Dcorp Db-Schema Folder is NOT present : " $NextFolder
                          New-Item -ItemType Directory -Path $NextFolder -ErrorAction Stop | Out-Null
                          write-host ">   Dcorp Db-Schema Folder is created : " $NextFolder
                    }

           }

           "ICORP" {
                    $InputFolder= $PackagesFolder + "Dcorp" 
                    $NextFolder=$PackagesFolder + "Icorp"
               
                    if (test-path $InputFolder) {
                        write-host ">   Input Db-Schema Folder is present : " $InputFolder    
                    }
                    else {
                          write-host ">>  Input Db-Schema Folder is NOT present : " $InputFolder
                          write-host "!!!     THERE IS SOMETHING WRONG     !!!" 
                          exit 1
                    }

  
                    if (test-path $NextFolder) {
                        write-host ">   Icorp Db-Schema Folder is present : " $NextFolder    
                    }
                    else {
                          write-host ">>  Icorp Db-Schema Folder is NOT present : " $NextFolder
                          New-Item -ItemType Directory -Path $NextFolder -ErrorAction Stop | Out-Null
                          write-host ">   Icorp Db-Schema Folder is created : " $NextFolder
                    }

           }

           "ACORP" {
                    $InputFolder= $PackagesFolder + "Icorp" 
                    $NextFolder=$PackagesFolder + "Acorp"

                    if (test-path $InputFolder) {
                        write-host ">   Input Db-Schema Folder is present : " $InputFolder    
                    }
                    else {
                          write-host ">>  Input Db-Schema Folder is NOT present : " $InputFolder
                          write-host "!!!     THERE IS SOMETHING WRONG     !!!" 
                          exit 1
                    }


                    if (test-path $NextFolder) {
                        write-host ">   Acorp Db-Schema Folder is present : " $NextFolder    
                    }
                    else {
                          write-host ">>  Acorp Db-Schema Folder is NOT present : " $NextFolder
                          New-Item -ItemType Directory -Path $NextFolder -ErrorAction Stop | Out-Null
                          write-host ">   Acorp Db-Schema Folder is created : " $NextFolder
                    }
 
           }

           "PCORP" {
                    $InputFolder= $PackagesFolder + "Acorp" 
                    $NextFolder=$PackagesFolder + "Pcorp"

                    if (test-path $InputFolder) {
                        write-host ">   Input Db-Schema Folder is present : " $InputFolder    
                    }
                    else {
                          write-host ">>   Input Db-Schema Folder is NOT present : " $InputFolder
                          write-host "!!!     THERE IS SOMETHING WRONG     !!!" 
                          exit 1
                    }


                    if (test-path $NextFolder) {
                        write-host ">   Pcorp Db-Schema Folder is present : " $NextFolder    
                    }
                    else {
                          write-host ">>  Pcorp Db-Schema Folder is NOT present : " $NextFolder
                          New-Item -ItemType Directory -Path $NextFolder -ErrorAction Stop | Out-Null
                          write-host ">   Pcorp Db-Schema Folder is created : " $NextFolder
                    }

           }


    }

    $InputFile=$InputFolder + "\" + $InputFileName

    write-host " "
    write-host " "

    # --------------------------------------------------------------------------------------------------------------------
    # 
    if ($Environment -ne "BUILD" -and $Environment -ne "EMERG") {
        & net use $DeploymentFolder /user:$($userid) $($pwd)
    }
       

    # --------------------------------------------------------------------------------------------------------------------
    # 
    if (test-path $DeploymentFolder) {
        write-host ">   Server Db-Schema Folder is present : " $DeploymentFolder  
    }
    else {
          write-host ">>  Server Db-Schema Folder is NOT present : " $DeploymentFolder
          write-host "!!!     THERE IS SOMETHING WRONG     !!!" 
          exit 1
    }


    # --------------------------------------------------------------------------------------------------------------------
    # 
    write-host ">   Getting content of : Logging_Load_DFs.txt (db-server)"
    write-host " "
    write-host " "
    $LogFile=$DeploymentFolder + "\Logging_Load_DFs.txt"
    #
    get-content $LogFile
    $LogFileContent=get-content $LogFile

    # --------------------------------------------------------------------------------------------------------------------
    # 
    #selecting the error files (if present)
    $ErrorFiles=$LogFileContent | where-object {$_ -match "errorfile"} 

    write-host " "
    write-host " "
    foreach ($ErrorFile in $ErrorFiles) {
             write-host ">>>     ErrorFile : " $ErrorFile.substring(52)
             $ErrorExit=$true
    }

    # --------------------------------------------------------------------------------------------------------------------
    # 
    
    write-host " "
    write-host " "
    write-host ">   Files present in input folder : " $InputFolder


    $PackageFileFolder=@()
    get-childitem -path $InputFolder  -File | sort-object | foreach-object {
                                                                            write-host "File : " $_.Name
                                                                            $PackageFileFolder+=$_.Name
                                                            }

    write-host " "
    write-host " "
    
    # --------------------------------------------------------------------------------------------------------------------
    #    

    foreach ($DbFile in $PackageFileFolder) {
        
                $MoveYN=$true

                foreach ($ErrorFile in $ErrorFiles) {
            
                        if ($DbFile -match $ErrorFile.substring(52)) { 
                            $MoveYN = $false
                            write-host ">>>   NO MOVE : " $dbfile "  >>>  CHECK Errorfile " 
                        } 
                } 
              
         
                if ($DbFile -match $InputFileName) {
                    $MoveYN = $false
                }

             
                if ($MoveYN) {
                    write-host ">>   Moved : " $DbFile "  to   " $NextFolder
                    $MoveFile= $InputFolder + "\" + $DbFile
                    move-item Filesystem::$MoveFile -Destination $NextFolder -force 
                }               
    }
    

    write-host " "
    write-host " "

    
    if ($ErrorExit) {
        write-host " "
        write-host " "
        write-host " "
        write-host "!!!   ERRORS DURING SCHEMA LOAD   !!!"

        exit 1
    }



    # --------------------------------------------------------------------------------------------------------------------
    # 
    #& net use * /d /yes | Out-Null


} # end of function Schema_Exec

# ====================================================================================================================
# 
#
# ====================================================================================================================

    
#---------------------------------------------------------------------------------------------------------------------
# Main Source folder of the schema changes

$PackagesFolder="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117\R" + $Release + "\DB-Schema\"

if (test-path $PackagesFolder) {
    write-host ">   Main Db-Schema Folder is present   : " $PackagesFolder    
}
else {
      write-host ">   Main Db-Schema Folder is NOT present"
      New-Item -ItemType Directory -Path $PackagesFolder -ErrorAction Stop | Out-Null
      
      write-host ">>  Main Db-Schema Folder is created" 
}

#
# --------------------------------------------------------------------------------------------------------------------
#                                                   Action
# --------------------------------------------------------------------------------------------------------------------


if ($Action -eq "prepare") {

    write-host "*** Prepare ***"
    Schema_Prep    
}


if ($Action -eq "executed") {

    write-host "*** Executed ***"
    Schema_Exec
}


# --------------------------------------------------------------------------------------------------------------------
# 
