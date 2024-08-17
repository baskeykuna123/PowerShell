clear
<# 
   Luc Mercken : 2019-12-30

   TALK-FRONT (Abstractie-laag)
   copy directories and files from RoundTable deployment directorie to Central B&I compil directorie
   cleanup B&I directorie   

   RTB deployment done on Packages folder 
#>




# Logging on disk
function Writelog ($data,$filepath)
{
	Add-Content $filepath -Value $data -Force
}

#----------------------------------------------------------------------------------------------------------------------

# Set variables
# Folders which will not be copied from deployment folder
$RestrictedFolders = "rtb_dbup",
                     "rtb_idat",
                     "rtb_inst",
                     "rtb_temp", 
 #                    "config",
                     "patchDB"

$WorkDirectory = "E:\BuildScripts"
$Destination = "E:\TALK11_Build_Front\"

#----------------------------------------------------------------------------------------------------------------------

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#----------------------------------------------------------------------------------------------------------------------

# Getting ReleaseNumber and VersionNumber
$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )
$Node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='TALK']")
$Release = $($node.Version).split('.')[0]
$Version=$Node.Version

Write-Host "Release : " $Release
Write-Host "Version : " $Version

#----------------------------------------------------------------------------------------------------------------------

# RTB releasefolder
$NewReleaseVersionFolder = [string]::Format("\\balgroupit.com\appl_data\BBE\Packages\TALKFRONT\R{0}\",$Release)
$NewReleaseFolder = Get-ChildItem FileSystem::$NewReleaseVersionFolder | Where-Object { $_.PSIsContainer  -and $_.Name -ieq "$Version"} | Select-Object -First 1
if(-not (Test-Path filesystem::$($NewReleaseFolder.FullName))){
	Write-Host "Invalid source path : " $NewReleaseFolder.FullName
	Exit 1
}

# Create Log File 
$LogFile = [String]::Format("{0}\logs\{1}_Front_copy_deploy.txt",$WorkDirectory,$Version)
if(-not(Test-Path $LogFile)){
	New-Item $LogFile -ItemType File -Force -ErrorAction Stop| Out-Null
}

$Date = Get-Date -DisplayHint DateTime
$NewReleaseFolder = $NewReleaseFolder.FullName
Writelog "=============================================" $LogFile
Writelog "Start Copy.... : $Date" $LogFile
Writelog "Source File    : $source" $LogFile
Writelog "Release folder : $NewReleaseFolder" $LogFile

#----------------------------------------------------------------------------------------------------------------------

# Copy items from new release folder to build directory
Get-ChildItem $NewReleaseFolder | ForEach-Object {
	$Folder = $_.Name
	if (-not ($RestrictedFolders -contains ($Folder))) {

		$FolderPath = $_.FullName
        Writelog "Copying From New Release to the Build directory $FolderPath" $LogFile

		Copy-Item "$FolderPath\*" -Destination $Destination 	 -Recurse -Force -Verbose 
	}
}

#----------------------------------------------------------------------------------------------------------------------


$Date = Get-Date -DisplayHint DateTime

Writelog "End copy       : $Date" $LogFile
Writelog "=============================================" $LogFile

get-content $LogFile 


#----------------------------------------------------------------------------------------------------------------------


#Remove all unwanted files in the destination folder

$Date = Get-Date -DisplayHint DateTime
write-host "============================================="
write-host "Start Delete Files " $Date

get-childitem -path $Destination * -include *.r, desktop*.pf, *protrace.*, test*.*, *.ds, *.pref, *.log, project.xml, talk.ini, ConUserLang.* -recurse | remove-item -force -ErrorAction Ignore


#remove unwanted directories and files inside these directories

$DeleteFolders = "walvis",
                 "dll64b",
                 "dmp",
                 "webservices"              
               
               
foreach ($Deletefolder in $deletefolders) {

    $Deletion= $Destination + "\"  + $DeleteFolder
    get-childitem -path $Deletion -include *.* -recurse -ErrorAction Ignore | remove-item -force -ErrorAction Ignore
    remove-item -path $Deletion -force -recurse -ErrorAction Ignore
}                 
$Date = Get-Date -DisplayHint DateTime
write-host "End   Delete Files " $Date
write-host "============================================="


