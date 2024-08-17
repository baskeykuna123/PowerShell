Param($Environment,$DeploymentVersions="")


if(!$Environment){
	$Environment='ICORP'
	$DeploymentVersions=""
}

Clear
Clear
switch ($Environment){ 
	  	"PARAM" { $PreEnv=""}
	  	"DCORP" { $PreEnv=""}
		"PRED" { $PreEnv=""}
		"EMRG" { $PreEnv=""}
		"DATAMIG" { $PreEnv=""}
		"MIG4" { $PreEnv=""}
        "ICORP" { $PreEnv="DCORP"}
		"ACORP" { $PreEnv="ICORP"}
		"PCORP" { $PreEnv="ACORP"}
     }

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#sorting versions in ascending order
#Variables
$ApplicationName="SASLOADER"
$templocation="C:\tempv14SASLOADER\"


if(!$DeploymentVersions){
	$exeproccmd="EXEC GetDeployedAppVersion @Application='$ApplicationName',@Environment='$Environment'"
	$currentVersion=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
    $currentVersion=$currentVersion.BuildVersion

        Write-Host "========================Version Package info===================="
	    Write-Host "Latest Version on $($Environment) : " $currentVersion
	    if($PreEnv){
		    #getting the latest verison in the previous environment
		    $exeproccmd="EXEC GetDeployedAppVersion @Application='$ApplicationName',@Environment='$PreEnv'"
		    $prevenv=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
		    $prevenv=$prevenv.BuildVersion
		
		    #getting Versions in between
		    $exeproccmd="EXEC GetBuildVersionsBetween @Application='$ApplicationName',@Environment='$Environment',@sourceVersion='$currentVersion',@targetVersion='$prevenv'"
		    $preversions=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
		    Write-Host "Latest Version on $($PreEnv)      : " $prevenv
		    if($currentVersion -ieq $prevenv){
			    Write-Host "There are no new versions to be packaged for $($Environment). Error in packaging"
			    Exit 1
		}
	}
	    else {
		    $exeproccmd="EXEC [GetBuildVersionsAfter] @Application='$ApplicationName',@Environment='$Environment',@sourceVersion='$currentVersion'"
		    $preversions=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
		
	    }

	if(!$preversions){
		Write-Host "No versions to deploy . Aborting "
		Exit 1
	}

	$DeploymentVersions=@()
	Foreach($row in $preversions){
		$row.Version
		$DeploymentVersions+=([string]$row.Version)
	}
}
else{
	Write-Host "NOTE : Deploying Patch versions . Param Import will be done based on the Input Parameter"
	$DeploymentVersions=@($DeploymentVersions.Split(','))
}



$currentdate=Get-Date -Format "yyyy-MM-dd"


$NewVersion=$DeploymentVersions
$Release="R"+$newVersion.split('.')[0]
$currentReleasefolder=Join-Path $Global:SASLOADERSourcePackages -ChildPath "$Release\"
$latestVersionFolder=Join-Path $Global:SASLOADERSourcePackages -ChildPath "$Release\$($NewVersion)"
$UploadTemplatefolder=join-path $Global:SASLOADERSourcePackages -ChildPath "Templates\UploadTemplate\"

#update the properties specific to the Environemnt for deployment
$propertiesfile=[string]::Format("{0}{1}_{2}Deploy.Properties",$Global:JenkinsPropertiesRootPath,$Environment,$ApplicationName)
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

$ClevEnv=getClevaEnvironment -Environment $Environment
$uploadfoldername=[string]::Format("{0}_{1}_SASLOADER_{2}",$currentdate,$ClevEnv,$seq)

$uploadfolder=join-path $templocation -ChildPath "$uploadfoldername\"
New-Item $uploadfolder -ItemType directory -Force |Out-Null
Copy-Item Filesystem::"$UploadTemplatefolder\*" -Destination $uploadfolder -Force -Recurse
Copy-Item Filesystem::"$latestVersionFolder\Server\*" -Destination	"$uploadfolder\server\" -Recurse -Force
Copy-Item Filesystem::"$latestVersionFolder\version" -Destination	"$uploadfolder\" -Recurse -Force

#Adding Environment Specific batches
$Mparfilepath=(Get-ChildItem Filesystem::$latestVersionFolder -Filter "mpars_*.txt" -Force).FullName

foreach($version in $DeploymentVersions){
	$currentVersionfolder=Join-Path $currentReleasefolder -ChildPath $version
	$currentVersionmpar=(Get-ChildItem Filesystem::$currentVersionfolder -Filter "mpars_*.txt" -Force).FullName
	if(test-path Filesystem::$currentVersionmpar){
		$mpars+=[System.IO.File]::ReadAllLines($currentVersionmpar)
		
	}
}

$EnvBatches=join-path $($latestVersionFolder) -ChildPath "batch\$Environment"
If($Environment -ne "PARAM"){ 
    copy-item Filesystem::"$EnvBatches\*" -Destination "$uploadfolder\batch\" -Force -Recurse
	}
else{
	Write-Host "WARNING: No batch deployments for $Environment"
}

$dbfolder=join-path $uploadfolder -childpath "\database\SASLOADER\"

#creating the DB file
$dbscripttxtfile=join-path $dbfolder -childpath "\deployScripts.txt"
foreach($version in $DeploymentVersions){
	Write-Host "Packaging SQL scripts for Version :" $version
	$selectQuery="Select * from SASLOADERVersions where SASLOADER_Version='$version'"
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	$CurrentSQLVersion=$select.SASLOADER_VERSION
	if($select){
		$ClevaDBpackage=[String]::Format("{0}{1}\database\SASLOADER\SASLOADER_{1}.zip",$currentReleasefolder,$CurrentSQLVersion)
        write-host $ClevaDBpackage 
		$filename=split-path Filesystem::$ClevaDBpackage -leaf  
		Copy-Item  Filesystem::$ClevaDBpackage -Destination $dbfolder -Force -Recurse
		Add-Content Filesystem::$dbscripttxtfile -Value $filename
	}
	
}

Write-Host "New $Environment Version Info"
Write-Host "================================================================="
Write-Host "Baloise Version            :" $NewVersion
Write-Host "MIDC version               :" $select.MATC_VERSION	
Write-Host "Upload Folder              :" $uploadfolder
Write-Host "================================================================="

$destinationpath="/mercator/work/BUILD/DeploysV14/"
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
Remove-Item -Path $templocation -Recurse -Force