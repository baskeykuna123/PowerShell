Param($Environment,$DeploymentVersions)
##

if(!$Environment){
	$Environment='MIG2'
	$DeploymentVersions="99.22.0.0"
}

Clear


#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$date=[DateTime]::Now.ToString("yyyy-MM-dd")
#sorting versions in ascending order

$DeploymentVersions=@($DeploymentVersions.Split(','))
$NewVersion=$DeploymentVersions[-1]
$Release="R"+$NewVersion.split('.')[0] 

$Deliveryfolder="\\balgroupit.com\appl_data\BBE\Packages\InjectR\Sources\$($Release)\$Environment\"
$templatelocation="\\balgroupit.com\appl_data\BBE\Packages\InjectR\Sources\Templates\DeploymentTemplates_InjectR\"
$templocation="D:\buildteam\temp\"
$currentdate=Get-Date -Format "yyyy-MM-dd"


#update the properties 
$propertiesfile=[string]::Format("{0}{1}_InjectRDeploy.Properties",$Global:JenkinsPropertiesRootPath,$Environment)
$propfile=getproperties -FilePath $propertiesfile
$propfile["Environment"]=$Environment
$propfile["version"]=$NewVersion
if($propfile["ReleaseDate"] -ieq $currentdate){
	$propfile["ReleaseNumber"]=$seq=([int]$propfile["ReleaseNumber"])+1
}
else {
	$propfile["ReleaseNumber"]=$seq=1
}
$propfile["ReleaseDate"]=$currentdate

setproperties -FilePath $propertiesfile -Properties $propfile

$latestVersionFolder=Join-Path $Deliveryfolder -ChildPath $NewVersion

$uploadfoldername=[string]::Format("{0}_{1}_INJECTR_{2}",$currentdate,$Environment,$seq)
$uploadfolder=join-path $templocation -ChildPath "$($uploadfoldername)\"
New-Item Filesystem::$uploadfolder -ItemType directory -Force |Out-Null
Copy-Item Filesystem::"$($templatelocation)*" -Destination	Filesystem::"$($uploadfolder)\" -Recurse -Force
Copy-Item Filesystem::"$($latestVersionFolder)\server\*" -Destination  Filesystem::"$($uploadfolder)\server\" -Force -Recurse
copy-item Filesystem::"$($latestVersionFolder)\version" -Destination  Filesystem::"$($uploadfolder)\" -Force -Recurse

$dbfolder=join-path $uploadfolder -childpath "\database\InjectR\"
$dbscripttxtfile=join-path $dbfolder -childpath "\deployErrorScripts.txt"

foreach($version in $DeploymentVersions){
	Write-Host "Checking Version :" $version
	$selectQuery="Select * from InjectRVersions where InjectR_Version='$version'"
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	if($select){
		$InjectRDBpackage=[String]::Format("{0}\{1}\database\InjectR_{1}.zip",$Deliveryfolder,$select.InjectR_Version)
		$filename=split-path $InjectRDBpackage -leaf  
		Copy-Item  Filesystem::$InjectRDBpackage -Destination Filesystem::"$($uploadfolder)\database\InjectR\" -Force -Recurse
		Add-Content Filesystem::$dbscripttxtfile -Value $filename
	}
}
	
Write-Host "New $Environment Version Info"
Write-Host "================================================================="
Write-Host "Baloise Version            :" $NewVersion
Write-Host "InjectR version            :" $select.MIDC_Version	
Write-Host "Upload Folder              :" $uploadfolder
Write-Host "================================================================="

$destinationpath="/mercator/work/BUILD/Deploys/"
Write-Host "Uploading.. files to the server"
$transferOptions=New-Object WinSCP.TransferOptions
$transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
$SessionOptions=CreateNewSession -FTPName "JBOSSDeployment"
$Session=New-Object WinSCP.Session
$Session.Open($SessionOptions)
$Res=$Session.PutFiles($uploadfolder,$destinationpath,$false,$transferOptions)
$Res.Transfers
if($Res.IsSuccess){
	Write-Host "Upload completed for $ziplocation successfully....."
}
$Session.Dispose()