# 2020-02-03 : Luc Mercken 
# TALK : artefacts which are not included in the build.pl and belonging to a release deployment
#        are put together on the release packagages folder, source is RoundTable deployments
#        From this central point they deployed to I-A-P
#        Citrix folder, Db-server (001) and Batch-server (003)
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
#
#
Param($Environment)
Clear



if(!$Environment){
   $Environment="ICORP"
}

# --------------------------------------------------------------------------------------------------------- #
#                        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#                                      SOURCES are located on packages folder   
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

$PackageFolder="\\balgroupit.com\appl_data\BBE\Packages\talk\R" + $release + "\Talk"

# Check if package folder exist
#  

if (Test-Path $PackageFolder) {
    write-host "  Artefacts Package folder is present"
}
else {
      
      write-host "  Artefacts Package folder is NOT PRESENT "
      write-host "  " $PackageFolder
      exit 0
}


write-host "Artefacts Package Release Folder : " $PackageFolder
write-host


$PackageSubFolder=@()
get-childitem -path $PackageFolder   -Directory | foreach-object { $PackageSubFolder+=$_.Name }

#----------------------------------------------------------------------------------------------------------------------

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

#Server Locations
$001_DeploymentFolder=[string]::Format("\\svw-be-tlkc{0}001.balgroupit.com\F$\Talk\{1}\MncafeAc",$serval,$Environment)
$003_DeploymentFolder=[string]::Format("\\svw-be-tlkc{0}003.balgroupit.com\E$\Talk3\{1}\MncafeAc",$serval,$Environment)

#Citrix Client TransferLocations
$Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_OneClient\TALK3\{1}-Current-RZ3\MnCafeAc",$global:TransferShareRoot,$Environment)
if ($Environment -ieq "PCORP") {
    $Citrix_DeploymentFolder=[string]::Format("{0}TALK\Citrix_OneClient\TALK3\{1}-Current\MnCafeAc",$global:TransferShareRoot,$Environment)
}


write-host "DB Server 001    :  " $001_DeploymentFolder
write-host "Batch Server 003 :  " $003_DeploymentFolder
write-host "Citrix           :  " $Citrix_DeploymentFolder
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
foreach ($Folder in $PackageSubFolder) {
         if ($Folder -ne "Config") {
             $CopyFolder = $PackageFolder + "\" + $Folder
             Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$Citrix_DeploymentFolder -Force -recurse
         }
}



#Db Server 001,  Batch Server 003
#Connecting to share with the user
write-host 
write-host
Write-Host 	 "Deploying To Servers : " $001_DeploymentFolder "  -  " $003_DeploymentFolder

& net use $001_DeploymentFolder /user:$($userid) $($pwd)
& net use $003_DeploymentFolder /user:$($userid) $($pwd)


foreach ($Folder in $PackageSubFolder) {
         $CopyFolder = $PackageFolder + "\" + $Folder
         write-host "     Copy Folder : " $CopyFolder
         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$001_DeploymentFolder -Force -recurse
         Copy-Item Filesystem::$CopyFolder -Destination Filesystem::$003_DeploymentFolder -Force -recurse
}




& net use * /d /yes | Out-Null
