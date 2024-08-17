Param($envName)
Import-Module WebAdministration
#$EnvName="DCORP"
$globalManifest = '\\shw-me-pdnet01\Repository\GlobalReleaseManifest.xml'
$xml = [xml](Get-Content $globalManifest )
$deploymentLocation = "E:\Baloise\Services\ESBBosService\"
$MercatorWebBrokerSourceFolder = "E:\Baloise\WebSite\MyBaloiseBroker\"
$MercatorWebBrokerDestinationFolder = "E:\Baloise\WebSite\MyBaloiseWebBrokerEsbBOS\"
$serviceExeName = "Mercator.Esb.Tools.EsbBoSimulator.Service.exe"
#Get the application no to be updated
$node = $xml.SelectSingleNode("/Release/environment[@Name='$envName']/Application[@Name='ESBBOS']")
$DeploymentSourcepath = [string]::Format("\\shw-me-pdnet01\B.ESBBOS\ESBBOS_{0}\", $node.Version)
Write-Host "================================================================================="
Write-Host "Envrioment               : "$EnvName
Write-Host "Deployment Version       : "$node.Version
Write-Host "Deployment Source folder : "$DeploymentSourcepath
Write-Host "================================================================================="

Write-Host "Checking for the the ESBBOS Service per requisities"
if (-not(Test-Path $deploymentLocation)) {
    Write-Host "Creating Service Folder........$deploymentLocation"
    New-Item -ItemType Directory $deploymentLocation
}
if (-not (Get-Service  -Name "EsbBoSimulator")) {
    Write-Host "Creating Service........'ESB BackOfficeService Simulator'"
    new-service -Name "EsbBoSimulator" -DisplayName "ESB BackOfficeService Simulator" -StartupType Automatic -BinaryPathName $deploymentLocation$serviceExeName
}

if($true)
{
    asdas
}
Write-Host "Pre-Deployment Check completed....."

Write-Host "Deploying Service"

Write-Host "Stopping the ESBBOS Service............"
Stop-Service "EsbBoSimulator"  -force
Copy-Item "$DeploymentSourcepath\*" -Destination $deploymentLocation -Force -Recurse


#make copy of MercatorWebBroker folder
if (Test-Path $MercatorWebBrokerDestinationFolder) {
    Write-Host "Deleting Folder........$MercatorWebBrokerDestinationFolder"
    Remove-Item  "$MercatorWebBrokerDestinationFolder\*" -Recurse -Force
}
Write-Host "Creating Folder........$MercatorWebBrokerDestinationFolder"

Copy-Item "$MercatorWebBrokerSourceFolder\*" -Destination $MercatorWebBrokerDestinationFolder -Force -Recurse
$configxml = [XML](Get-Content "$MercatorWebBrokerDestinationFolder\web.config")
$endpoint = $configxml.SelectSingleNode("//system.serviceModel/client/endpoint")
$endpoint.address = "net.tcp://localhost:6002/"
$configxml.Save("$MercatorWebBrokerDestinationFolder\web.config")
Start-Service -Name "EsbBoSimulator"

