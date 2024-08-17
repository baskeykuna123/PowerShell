# 2019-07-02 : Luc Mercken : added Ecorp
# 2019-12-05 : Luc Mercken : start deploy IAP from packages folder (Release_Version folder)
# 2020-06-09 : Luc Mercken : added Lkey-account and password from Db
# 2020-08-12 : Luc Mercken : added Version_Title, a update of the application Title
#
#
Param($Environment)
Clear



if(!$Environment){
$Environment="ICORP"
}

#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#
#----------------------------------------------------------------------------------------------------------------------
# Getting ReleaseNumber and VersionNumber in case of a IAP deployment

if($Environment -eq "ICORP" -Or $Environment -eq "ACORP" -Or $Environment -eq "PCORP") {
    $xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )


    $Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")
    $Release = $($node.Version).split('.')[0]
    $Version=$Node.Version
    Write-Host "Release : " $Release "          Version : " $Version
    
    #----------------------------------------------------------------------------------------------------------------------
    # Source folder of the build.pl,  central destination folder(package, Talk, Release and Version

    $PackagesFolder="\\balgroupit.com\appl_data\BBE\Packages\TALK"

    # $ReleaseVersionFolder=$PackagesFolder + "\R" + $Release + "\" + $Version
    # $BuildSourceFile= $ReleaseVersionFolder + "\build.pl"

    $ReleaseBuildFolder=$PackagesFolder + "\R" + $Release + "\Build"
    $BuildSourceFile= $ReleaseBuildFolder + "\build.pl"
}
#

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



#--------------------------------------------------------------------------------------------------------------------------
#BuildSourceFile : Depending I-A-P,  Dcorp,  Ecorp
# OLD Code ,  replaced  see higher    $BuildSourceFile="\\svw-be-tlkbp001.balgroupit.com\BuildScripts\Build_Versions\Laatste\build\build.pl"


if($Environment -match "DCORP"){
	$BuildSourceFile="\\svw-be-tlkbp001.balgroupit.com\BuildScripts\DEV_Dcorp\Build_Versions\Laatste\build\build.pl"
}


if($Environment -match "ECORP"){
	$BuildSourceFile="\\svw-be-tlkbp001.balgroupit.com\BuildScripts\ECORP\Build_Versions\Laatste\build\build.pl"
}


#--------------------------------------------------------------------------------------------------------------------------
# check if neede file is present,  if not stop procedure
if(-not(Test-Path FileSystem::$BuildSourceFile)){
	Write-Host 	"The Build Source File not found : $BuildSourceFile"
	Write-Host 	"Deployment Failed"
	Exit 1
}
write-host "BuildSourceFile : " $BuildSourceFile

#--------------------------------------------------------------------------------------------------------------------------

#citrix Client TransferLocations
$DeloymentFolders=@()
#$DeloymentFolders+=[string]::Format("{0}TALK\Citrix_OneClient\TALK\{1}-Current",$global:TransferShareRoot,$Environment)

if ($Environment -ieq "PCORP") {
    $DeloymentFolders+=[string]::Format("{0}TALK\Citrix_OneClient\TALK3\{1}-Current",$global:TransferShareRoot,$Environment)
}
else {
      $DeloymentFolders+=[string]::Format("{0}TALK\Citrix_OneClient\TALK3\{1}-Current-RZ3",$global:TransferShareRoot,$Environment)
}

#deployment Servers
$DeloymentFolders+=[string]::Format("\\svw-be-tlkc{0}003.balgroupit.com\e$\Talk3\{1}",$serval,$Environment)
$DeloymentFolders+=[string]::Format("\\svw-be-tlkc{0}001.balgroupit.com\F$\Talk\{1}",$serval,$Environment)


foreach($folder in $DeloymentFolders){
	#Connecting to share with the user
	Write-Host 	 "Deploying To : $folder"
	& net use $folder /user:$($userid) $($pwd)
	Copy-Item Filesystem::$BuildSourceFile -Destination Filesystem::$folder -Force -ErrorAction Stop
	
}

& net use * /d /yes | Out-Null



#--------------------------------------------------------------------------------------------------------------------------
# Updating the Application Title with the version number

$DbServer=[string]::Format("svw-be-tlkc{0}001.balgroupit.com",$Environment[0])

$TemplateFolder="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Templates\Talk\"



#----------------------------------------------------------------------------------------------------------------------
# a menu.pf file is generated from a template, some variables are replaced by actual data
# menu.pf : connect to STDDB db, executing OE_program


$Template_MenuFile=join-path $TemplateFolder -ChildPath "Template_Version_Title.pf"


$Run_MenuFile=join-path "E:\BuildScripts\RTB_Deploy\" -ChildPath "Version_Title.pf"


if (Test-Path $Run_MenuFile) {
    Remove-Item $Run_MenuFile -force -ErrorAction Ignore
}

   

(Get-Content -Path $Template_MenuFile) | Foreach-Object {
    $_ -replace 'xCorp', $Environment `
       -replace 'RelVersion', $Version `
       -replace 'DbServer', $DbServer `       
     } | Set-Content -path $Run_MenuFile


#----------------------------------------------------------------------------------------------------------------------
# Executing Version_Title

if ($Environment -ieq "PCORP") { }
else {
      $BatFile="E:\BuildScripts\RTB_Deploy\Version_Title.bat"
      cmd.exe /C $Batfile
}

