if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
Clear


$Action="reserve"
$Environments="PLAB","DCORP","ICORP","ACORP","PCORP"
$Applications="CLEVA","MyBaloiseWebInternal","MyBaloiseWebBroker","MyBaloiseWebPublic","ESB","MyBaloiseClassic","CentralDataStore","NINA","TALK","Backend","BrokerLegacy","InternalLegacy","EAI","MDM","TaskCreateEngine","NINADB","BDA"
foreach($Application in $Applications){
	foreach($Environment in $Environments){
		ManageJenkinsResources -Environment $Environment -Action $Action -Application $Application	
	}
}

