# 2020-02-03 : Luc Mercken 
# TALK : artefacts which are not included in the build.pl and belonging to a release deployment
#        are put together on the release packagages folder, source is RoundTable deployments
#        From this central point they deployed to I-A-P
#        Citrix folder, Db-server (001) and Batch-server (003)
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-12-30 : Luc Mercken : OE117 version, servernames=DNS Alias, folder names, citrix folder
#
# 2021-02-17 : not all of artefacts should be copied to client folders,  because this is a extract from GIT
#
# 2021-04-27 : TALKOLAP and TALKWS added
# 2021-04-28 : Dcorp artefacts not in packages  but on the build-server
# 2021-05-12 : OE116 Version on OE116 locations
#
Param($Environment)
Clear



if(!$Environment){ $Environment="DCORP" }

# --------------------------------------------------------------------------------------------------------- #
#                        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#                                      SOURCES are located on packages folder              TEST  folders find test   -WHATIF  in use !!!!
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
Write-Host "Release : " $Release 
                                                                       

if ($Environment -eq "DCORP") {
       $PackageFolder_TALK="E:\GitSources\CleanUp\CleanUp_TALK_Develop" 
       $PackageFolder_TALKWS="E:\GitSources\CleanUp\CleanUp_TALKWS_Develop" 
       $PackageFolder_TALKOLAP="E:\GitSources\CleanUp\CleanUp_TALKOLAP_Develop" 
}
else {
                                                                              
       $PackageFolder_TALK="\\balgroupit.com\appl_data\BBE\Packages\TALK\R" + $release + "\TALK"
       $PackageFolder_TALKWS="\\balgroupit.com\appl_data\BBE\Packages\TALK\R" + $release + "\TALKWS"
       $PackageFolder_TALKOLAP="\\balgroupit.com\appl_data\BBE\Packages\TALK\R" + $release + "\TALKOLAP"

                                                                              #TEST  TEST  TEST
       #$PackageFolder_TALK="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117_TEST\R" + $release + "\TALK"
       #$PackageFolder_TALKWS="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117_TEST\R" + $release + "\TALKWS"
       #$PackageFolder_TALKOLAP="\\balgroupit.com\appl_data\BBE\Packages\TALK_OE117_TEST\R" + $release + "\TALKOLAP"

}
#----------------------------------------------------------------------------------------------------------------------
# Check if package folders exists
# 
if (Test-Path $PackageFolder_TALK) {
    write-host "  Artefacts folder  TALK  is present  :  " $PackageFolder_TALK
}
else {
      
      write-host "  Artefacts folder  TALK  is NOT PRESENT "
      write-host "  " $PackageFolder_TALK
      exit 0
}
write-host

if (Test-Path $PackageFolder_TALKWS) {
    write-host "  Artefacts folder  TALKWS  is present  :  " $PackageFolder_TALKWS
}
else {
      
      write-host "  Artefacts folder  TALKWS  is NOT PRESENT "
      write-host "  " $PackageFolder_TALKWS
      exit 0
}
write-host

if (Test-Path $PackageFolder_TALKOLAP) {
    write-host "  Artefacts folder  TALKOLAP  is present  :  " $PackageFolder_TALKOLAP
}
else {
      
      write-host "  Artefacts folder  TALKOLAP  is NOT PRESENT "
      write-host "  " $PackageFolder_TALKOLAP
      exit 0
}
write-host

#----------------------------------------------------------------------------------------------------------------------

$PackageSubFolder_TALK=@()
get-childitem -path $PackageFolder_TALK       -Directory | foreach-object { $PackageSubFolder_TALK+=$_.Name }

$PackageSubFolder_TALKWS=@()
get-childitem -path $PackageFolder_TALKWS     -Directory | foreach-object { $PackageSubFolder_TALKWS+=$_.Name }

$PackageSubFolder_TALKOLAP=@()
get-childitem -path $PackageFolder_TALKOLAP   -Directory | foreach-object { $PackageSubFolder_TALKOLAP+=$_.Name }

#----------------------------------------------------------------------------------------------------------------------

# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !

$SaveEnvironment=$Environment

if ($Environment -eq "ECORP") {    
    $Environment = "ACORP" 
}


$serval=$Environment[0]

#retrieve the User and password from the DB 
#$Userid=get-Credentials -Environment $Environment -ParameterName  "TALKServerUser"
#$Pwd=get-Credentials -Environment $Environment -ParameterName  "TALKServerPassword"

$Environment=$SaveEnvironment

# ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !


#$Environment="ICORP"
switch($Environment){
	"DCORP" {
				$serval="d"
				$userid="balgroupit\L001234"
				$pwd="Dp6unFoU" #| ConvertTo-SecureString -asPlainText -Force
            }

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

	"ECORP" {
				$serval="a"
				$userid="balgroupit\L001097"
				$pwd="Basler09" #| ConvertTo-SecureString -asPlainText -Force
			}

	"PCORP" {
				$serval="p"
				$userid="balgroupit\L001129"
				$pwd="PMerc_11" #| ConvertTo-SecureString -asPlainText -Force
			}
}

#----------------------------------------------------------------------------------------------------------------------
#
#Application Server Locations

                                                                                                                          
    $App_DeploymentFolder=[string]::Format("\\svw-be-tlkc{0}001.balgroupit.com\F$\Talk",$serval)
    $App_DeploymentFolder_TALK=[string]::Format("\\svw-be-tlkc{0}001.balgroupit.com\F$\Talk\{1}\MncafeAc",$serval,$Environment)
    $App_DeploymentFolder_TALKWS=[string]::Format("\\svw-be-tlkc{0}002.balgroupit.com\F$\Talk\DCORPWS",$serval)
    $App_DeploymentFolder_TALKOLAP=[string]::Format("\\svw-be-tlkc{0}001.balgroupit.com\F$\Talk\{1}Olap",$serval,$Environment)

    #Batch Server Locations
                                                                                                    
    $Batch_DeploymentFolder_TALK=[string]::Format("\\svw-be-tlkc{0}003.balgroupit.com\E$\Talk3\{1}\MncafeAc",$serval,$Environment)

    #Citrix Client TransferLocations
  
    if ($Environment -ieq "PCORP") {
        $Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_OneClient\TALK3\{1}-Current\MnCafeAc",$global:TransferShareRoot,$Environment)
    }
    else {
          $Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_OneClient\TALK3\{1}-Current-RZ3\MnCafeAc",$global:TransferShareRoot,$Environment)
    }
  
 

write-host "App Server TALK     :  " $App_DeploymentFolder_TALK
write-host "App Server TALKWS   :  " $App_DeploymentFolder_TALKWS
write-host "App Server TALKOLAP :  " $App_DeploymentFolder_TALKOLAP
write-host "Batch Server        :  " $Batch_DeploymentFolder_TALK
write-host "Citrix              :  " $Citrix_DeploymentFolder
write-host
write-host




# =================================================================================================================================
# deployment source folders and attributes

#Citrix
# Connecting to share with the user
write-host
write-host
Write-Host 	 "Deploying To Citrix : " $Citrix_DeploymentFolder

& net use $Citrix_DeploymentFolder /user:$($userid) $($pwd)

# ---------------------------------------------------------
# no need to copie "config" folder in  Citrix folders     !
# ---------------------------------------------------------
foreach ($Folder in $PackageSubFolder_TALK) {
         if ($Folder -ne "Config") {
             $CopyFolder = $PackageFolder_TALK + "\" + $Folder
             write-host "     Copy Folder Citrix : " $CopyFolder
             Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$Citrix_DeploymentFolder -Force -recurse -WhatIf
         }
}



#App Server ,  Batch Server 
#Connecting to share with the user
write-host 
write-host
Write-Host 	 "Deploying To Application Server : " $App_DeploymentFolder_TALK 
Write-Host 	 "Deploying To Batch Server       : " $Batch_DeploymentFolder_TALK
Write-Host 	 "Deploying To Front Server       : " $App_DeploymentFolder_TALKWS

& net use $App_DeploymentFolder /user:$($userid) $($pwd)
& net use $Batch_DeploymentFolder_TALK /user:$($userid) $($pwd)
& net use $App_DeploymentFolder_TALKWS /user:$($userid) $($pwd)


foreach ($Folder in $PackageSubFolder_TALK) {
         $CopyFolder = $PackageFolder_TALK + "\" + $Folder
         write-host "     Copy Folder TALK : " $CopyFolder
         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$App_DeploymentFolder_TALK -Force -recurse -WhatIf
         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$Batch_DeploymentFolder_TALK -Force -recurse -WhatIf
}

write-host
write-host

foreach ($Folder in $PackageSubFolder_TALKWS) {
         $CopyFolder = $PackageFolder_TALKWS + "\" + $Folder
         write-host "     Copy Folder TALKWS : " $CopyFolder
         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$App_DeploymentFolder_TALKWS -Force -recurse -WhatIf    
}

write-host
write-host

foreach ($Folder in $PackageSubFolder_TALKOLAP) {
         $CopyFolder = $PackageFolder_TALKOLAP + "\" + $Folder
         write-host "     Copy Folder TALKOLAP : " $CopyFolder
         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$App_DeploymentFolder_TALKOLAP -Force -recurse -WhatIf        
}


& net use * /d /yes | Out-Null
