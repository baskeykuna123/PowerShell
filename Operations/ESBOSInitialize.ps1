Param($Source,$envName)
write-host Preparing the Build Directory
#$globalManifest = '\\shw-me-pdnet01\Repository\GlobalReleaseManifest.xml'
$xml = [xml](Get-Content $global:ReleaseManifest )
#Get the application no to be updated
$node=$xml.SelectSingleNode("/Release/environment[@Name='$envName']/Application[@Name='ESBBOS']")
$buildbase="\\SHW-ME-PDNET01\f$\"+"B.ESBBOS"
$Servicesource=[string]::Format("\\shw-me-pdnet01\{0}_DEBUG_TOOLSESBBOSIMULATOR_LATEST\1.0\",$node.ParentNode.MercatorBuildVersion)
$version=$node.Version
if(-NOT (Test-path $buildbase)){
New-Item -ItemType Directory -Path $buildbase
}
$fname=$version
$newbuildfolder=$buildbase+"\ESBBOS_"+$fname
New-Item -ItemType Directory -Path $newbuildfolder

copy-item "$Servicesource*.dll" -destination $newbuildfolder -Force -Recurse
copy-item "$Servicesource*Service.exe" -destination $newbuildfolder -Force -Recurse

copy-item "$Source\*.xml" -destination $newbuildfolder -Force -Recurse
copy-item "$Source\*.deployment" -destination $newbuildfolder -Force -Recurse
copy-item "$Source\ResponseMesssages" -destination $newbuildfolder -Force -Recurse

Rename-Item "$newbuildfolder\Mercator.Esb.Tools.EsbBoSimulator.Service.exe.config.deployment" -NewName "Mercator.Esb.Tools.EsbBoSimulator.Service.exe.config"
#Set-ItemProperty -Path $newbuildfolder -Name IsReadOnly -Value $false -Force
