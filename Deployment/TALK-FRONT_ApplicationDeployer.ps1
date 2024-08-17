# 2019-08-06 : Luc Mercken : TALK Front Application Deployment Build -> I -> A -> P
# 2020-03-11 : change when Icorp also a copy to the packages folder,  version-folder
#              when I , A or P we take the (central) packages folder as input 
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
#                            destination name also with replacing values 
#
#
Param($Environment)
Clear



if(!$Environment){
$Environment="ICORP"
}

#----------------------------------------------------------------------------------------------------------------------
#
#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


#----------------------------------------------------------------------------------------------------------------------
# Getting ReleaseNumber and VersionNumber


$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )


$Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")
$Release = $($node.Version).split('.')[0]
$Version=$Node.Version

write-host 
write-host 
Write-Host "Release     : " $Release  "    Version : " $Version
write-host "Environment : " $Environment     
write-host 
write-host 


#----------------------------------------------------------------------------------------------------------------------
# 
$PackageFolder="\\balgroupit.com\appl_data\BBE\Packages\talkfront\R" + $release + "\DCORPWS"
$PackageVersionFolder="\\balgroupit.com\appl_data\BBE\Packages\talkfront\R" + $release + "\" + $Version + "_" + "DCORPWS"


#----------------------------------------------------------------------------------------------------------------------
# Check if package folder exist,  in case of Icorp : if present it should be deleted first and created again
# in case of Icorp :  Check if version folder exist, if present it should be deleted first and created again
# 

if (Test-Path $PackageFolder) {
    
    if ($Environment -ieq "ICORP") {
        write-host "  Package Release Folder is present and Environment=ICORP"
        write-host "          Clean existing Release Folder : " $PackageFolder
        remove-item Filesystem::$PackageFolder -Force -recurse -ErrorAction Ignore  
    }
} 


#
if (Test-Path $PackageFolder) {
    write-host "  Package Release Folder is present"
}
else {
      if ($Environment -ieq "ICORP") {

          $PackageFolderBaloise=$PackageFolder + "\Baloise"
          $PackageFolderTalkapp=$PackageFolder + "\Talkapp"

          New-Item -ItemType Directory -Path $PackageFolderBaloise -ErrorAction Stop | Out-Null
          New-Item -ItemType Directory -Path $PackageFolderTalkapp -ErrorAction Stop | Out-Null
          write-host "  Package Release Folder is created"
          start-sleep -seconds 5
      }
      else {
            write-host "  Package Release Folder is NOT PRESENT !!!"
            stop
      }
}

# Check if package version folder exist
#  
if ($Environment -ieq "ICORP") {

    if (Test-Path $PackageVersionFolder) {
        write-host "  Package Version Folder is present"
        write-host "          Clean existing Version Folder : " $PackageVersionFolder
        remove-item Filesystem::$PackageVersionFolder -Force -recurse -ErrorAction Ignore  
    }
    
    $PackageVersionFolderBaloise=$PackageVersionFolder + "\Baloise"
    $PackageVersionFolderTalkapp=$PackageVersionFolder + "\Talkapp"
              
    New-Item -ItemType Directory -Path $PackageVersionFolderBaloise -ErrorAction Stop | Out-Null
    New-Item -ItemType Directory -Path $PackageVersionFolderTalkapp -ErrorAction Stop | Out-Null

    write-host "  Package Version Folder is created"
    write-host
    start-sleep -seconds 5            
    
}


write-host "  Package Release Folder : " $PackageFolder
write-host


#----------------------------------------------------------------------------------------------------------------------
# in case the environment is ICORP, then first extra actions
# copying the artefact first to the packages folder : release folder and also to the version folder
# we have 2 main subfolders : Baloise and Talkapp 
#
                              
$Folders_Server=("TalkApp\App"),
                ("TalkApp\Group"),
                ("TalkApp\Prg"),
                ("TalkApp\Scripts"),
                ("TalkApp\System"),
                ("TalkApp\Trg_Cre"),
                ("TalkApp\Trg_del"),
                ("TalkApp\Trg_Wri"),
                ("TalkApp\Ul")


if ($Environment -ieq "ICORP") {
    $BuildSourceFolder_Server="\\svw-be-tlkbp001.balgroupit.com\e$\TALK11_Build_Front"
    $BuildSourceFiles_Server=@()
    foreach ($Folder in $Folders_Server) {
             $BuildSourceFiles_Server+=($BuildSourceFolder_Server + "\" + $Folder)                   
    }

    $BuildSourceFilesBaloise_Server=$BuildSourceFolder_Server + "\Baloise"
}


#----------------------------------------------------------------------------------------------------------------------
# when ICORP deployment source folders and attributes to packages folder
#
if ($Environment -ieq "ICORP") {
    write-host 
    write-host
    Write-Host 	 "Deploying To Packages : " $PackageFolder 
    Write-Host 	 "                      : " $PackageVersionFolder
    

    foreach($BuildSourceFile in $BuildSourceFiles_Server) { 
            write-host "From " $BuildSourceFile 
            Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$PackageFolderTalkapp -Force -recurse 
            Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$PackageVersionFolderTalkapp -Force -recurse                
    }

    write-host "From " $BuildSourceFilesBaloise_Server 
    Copy-Item Filesystem::$BuildSourceFilesBaloise_Server -Destination Filesystem::$PackageFolder -Force -recurse 
    Copy-Item Filesystem::$BuildSourceFilesBaloise_Server -Destination Filesystem::$PackageVersionFolder -Force -recurse                


}



#----------------------------------------------------------------------------------------------------------------------
# copying the artefact to the database server front (002) 
# source is allways the release package folder (at this moment !)
# we have 2 main subfolders : Baloise and Talkapp 
#

$BuildSourceFolder_Server=$PackageFolder
$BuildSourceFiles_Server=@()
foreach ($Folder in $Folders_Server) {
         $BuildSourceFiles_Server+=($BuildSourceFolder_Server + "\" + $Folder)                   
}

$BuildSourceFilesBaloise_Server=$BuildSourceFolder_Server + "\Baloise"


# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !

$SaveEnvironment=$Environment

if ($Environment -eq "ECORP") {    
    $Environment = "ACORP" 
}


$serval=$Environment[0]

#retrieve the User and password from the DB 
$Userid=get-Credentials -Environment $Environment -ParameterName  "TALKServerUser"
$Pwd=get-Credentials -Environment $Environment -ParameterName  "TALKServerPassword"

$Environment=$SaveEnvironment

$Destination=[string]::Format("\\svw-be-tlkc{0}002.balgroupit.com\F$\Talk\DCORPWS",$serval)
$Destination_Talkapp=$Destination + "\TalkApp"
write-host "TESt TEST  Destination = " $Destination

# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !



switch($Environment){
       "ICORP" {
                $Destination="\\svw-be-tlkci002.balgroupit.com\f$\Talk\DCORPWS" 
                $Destination_Talkapp=$Destination + "\TalkApp"

                $userid="balgroupit\L001235"
                $pwd="b5VfDZRN" #| ConvertTo-SecureString -asPlainText -Force  
               }

       "ACORP" {
                $Destination="\\svw-be-tlkca002.balgroupit.com\f$\Talk\DCORPWS" 
                $Destination_Talkapp=$Destination + "\TalkApp"

                $userid="balgroupit\L001097"
                $pwd="Basler09" #| ConvertTo-SecureString -asPlainText -Force  
               }

       "PCORP" {
                $Destination="\\svw-be-tlkcp002.balgroupit.com\f$\Talk\DCORPWS" 
                $Destination_Talkapp=$Destination + "\TalkApp"

                $userid="balgroupit\L001129"
                $pwd="PMerc_11" #| ConvertTo-SecureString -asPlainText -Force  
               }

}


#----------------------------------------------------------------------------------------------------------------------
# 
write-host "Network Connections : connect"
& net use $Destination /user:$($userid) $($pwd)  


#----------------------------------------------------------------------------------------------------------------------
# 
write-host "   Destination : " $Destination
write-host "               : " $Destination_Talkapp                  
   
# \Talkapp                
foreach($BuildSourceFile in $BuildSourceFiles_Server) { 
        write-host "   From " $BuildSourceFile 
        Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$Destination_Talkapp -Force -recurse 
                       
}

# \Baloise
write-host "   From " $BuildSourceFilesBaloise_Server 
Copy-Item Filesystem::$BuildSourceFilesBaloise_Server -Destination Filesystem::$Destination -Force -recurse 


#----------------------------------------------------------------------------------------------------------------------
# 
write-host
write-host "Network Connections : disconnect"
& net use $Destination /d /yes | Out-Null