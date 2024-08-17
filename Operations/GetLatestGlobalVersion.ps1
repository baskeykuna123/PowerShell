Param($Environment,$filepath)

clear
$globalManifest = '\\shw-me-pdnet01\Repository\GlobalReleaseManifest.xml'
$xml = [xml](Get-Content $globalManifest )
#Get the application no to be updated
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']")
Write-Host "GlobalRelease Version : " $node.GlobalReleaseVersion
Write-Host "FilePath              : " $filepath
Write-Host "Environment           : " $Environment
Set-Content $filepath -Value $node.GlobalReleaseVersion
