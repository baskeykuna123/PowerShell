PARAM($url,$version)
Clear-Host

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop
#update properties Script Path
$UpdatePropertiesScriptfile="$ScriptDirectory\ReleaseManagement\UpdateProperties.ps1"



if(!$url){
	$url = 'http://svw-be-tlkci001.balgroupit.com:8850/oeabl/soap/wsdl?targetURI=ApplicationVersion'
	$version="27.0.13.0"
	SetTalkApplicationVersion $version $url 
#	$url = 'http://svw-be-tlkca001.balgroupit.com:8850/oeabl/soap/wsdl?targetURI=ApplicationVersion'
#	$version="27.0.12.0"
#	SetTalkApplicationVersion $version $url 
}

