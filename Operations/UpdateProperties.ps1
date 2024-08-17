Param($Environment,$ApplicationName)
#$Environment="ICORP"
#$ApplicationName="MyBaloiseClassic"

#$globalManifest = '\\shw-me-pdnet01\Repository\GlobalReleaseManifest.xml'
$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )
#Get the application no to be updated
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='$ApplicationName']")
$globalver=$node.ParentNode.GlobalReleaseVersion
$buildver=$node.ParentNode.MercatorBuildVersion
$oldver=$ApplicationName+"_Version=.*"
$newver=$ApplicationName+"_Version="+$node.Version
$noliover=$node.NolioVersion
$branch=$node.TFSBranch

$PropertiesFileName=$Environment+"_"+$ApplicationName+".properties"
$propertiesfile ="e:\BuildTeam\buildproperties\$PropertiesFileName"
$fileinfo=Get-Content $propertiesfile

$fileinfo=$fileinfo -replace "GlobalReleaseVersion=.*","GlobalReleaseVersion=$globalver"
$fileinfo=$fileinfo -replace "MercatorBuildVersion=.*","MercatorBuildVersion=$buildver"
$fileinfo=$fileinfo -replace  $oldver,$newver
$fileinfo=$fileinfo -replace "NolioVersion=.*","NolioVersion=$noliover"
$fileinfo=$fileinfo -replace "TFSBranch=.*","TFSBranch=$branch"
Set-Content $propertiesfile $fileinfo
Write-Host "Updated $ApplicationName Properties file`n#########################"
foreach($val in $fileinfo)
{
Write-Host $val
}
Write-Host "#########################"


