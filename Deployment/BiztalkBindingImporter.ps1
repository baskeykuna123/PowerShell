
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

$ESBDeploymentFolder=Join-Path $global:ESBRootFolder -ChildPath "ESB"
#$DeploySequencelist="Mercator.Esb.SharedArtifacts.Cleva.BindingInfo.xml,Mercator.Esb.Service.TechnicalAccounting.BindingInfo.xml,Mercator.Esb.Service.Party.ThirdParty.BindingInfo.xml,Mercator.Esb.Service.Party.Intermediary.BindingInfo.xml,Mercator.Esb.Service.Party.Customer.BindingInfo.xml,Mercator.Esb.Service.Document.BindingInfo.xml,Mercator.Esb.Service.Contract.NonLife.SharedArtifacts.BindingInfo.xml,Mercator.Esb.Service.Contract.NonLife.Bpi.BindingInfo.xml ,Mercator.Esb.Service.Contract.NonLife.BindingInfo.xml,Mercator.Esb.Service.Address.BindingInfo.xml,Baloise.Esb.Service.TechnicalAccounting.BindingInfo.xml,Baloise.Esb.Service.Contract.NonLife.BindingInfo.xml"
$DeploySequencelist="Baloise.Esb.Service.BO.BaBe.BindingInfo.xml"
foreach($DeploySequenceXML in $DeploySequencelist.Split(',')){
$DeploySequenceName=$DeploySequenceXML -ireplace ".BindingInfo.xml",""
$ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $DeploySequenceName   
$bindingfilepath=[string]::Format("{0}\{1}\Deployment\bindingfiles\{2}",$ESBDeploymentFolder,$ApplicationShortName,$DeploySequenceXML)
$bindingfilepath
$ApplicationShortName
Import-BindingFile -ApplicationName $DeploySequenceName -BindingFilePath  | Add-Content "$($ESBDeploymentFolder)\logs\20181412.txt" -Path  -Force
}


if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

$ESBDeploymentFolder=Join-Path $global:ESBRootFolder -ChildPath "ESB"
$DeploySequencelist="Mercator.Esb.Service.Contract.NonLife.Bpi.BindingInfo.xml,Mercator.Esb.Service.Contract.NonLife.BindingInfo.xml,Mercator.Esb.Service.Address.BindingInfo.xml,Baloise.Esb.Service.TechnicalAccounting.BindingInfo.xml,Baloise.Esb.Service.Contract.NonLife.BindingInfo.xml"
foreach($DeploySequenceXML in $DeploySequencelist.Split(',')){
$DeploySequenceName=$DeploySequenceXML -ireplace ".BindingInfo.xml",""
$ApplicationShortName=GetApplicationDeploymentFolder -ApplicationName $DeploySequenceName   
$bindingfilepath=[string]::Format("{0}\{1}\Deployment\bindingfiles\{2}",$ESBDeploymentFolder,$ApplicationShortName,$DeploySequenceXML)
$bindingfilepath
$ApplicationShortName
Import-BindingFile -ApplicationName $DeploySequenceName -BindingFilePath $bindingfilepath  | Add-Content  -Path "$($ESBDeploymentFolder)\logs\20181412.txt" -Force
}