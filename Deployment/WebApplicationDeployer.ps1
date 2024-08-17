Param($Envrionment,$websiteName,$buildnumber,$ApplicationName)
Clear
#$ApplicationName="BrokerLegacySSM"
#$Envrionment="DCORP"
#$webAppName='BaloiseWeb.Broker.Legacy.SSM'
#$buildnumber='DEV_BrokerLegacy_20170520.2'

#load WebDeployer function file
. ".\WebDeployer.ps1"

IISRESET /STOP

WebDeployer -Envrionment $Envrionment -websiteName $websiteName -buildnumber $buildnumber -ApplicationName $ApplicationName -IsWebSite $false

IISRESET /START

