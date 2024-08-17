$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"
if($Env:COMPUTERNAME -ieq "svw-me-pcleva01")
{
clear
$global:CLEVASourcesFolder="\\balgroupit.com\appl_data\BBE\Packages\Cleva\Sources\"
$global:CLEVADeploymentPacakges="\\balgroupit.com\appl_data\BBE\Packages\Cleva\Packages\"
$global:ITN=Join-path $global:CLEVASourcesFolder -childpath "ITN\"
$global:Tarification=Join-path $global:CLEVASourcesFolder -childpath "tarification\"
$global:paramScripts=Join-path $global:CLEVASourcesFolder -childpath "ParameterizationScripts\"
$global:MIDC=Join-path $global:CLEVASourcesFolder -childpath "MIDC\"
$global:InitialInstall=Join-path $global:CLEVASourcesFolder -childpath "InitialInstallation"

#Templates
$global:EnvironmentTemplate=join-path $global:CLEVASourcesFolder -childpath "Templates\EnvionmentSh.txt"
$global:ITNTemplate=join-path $global:CLEVASourcesFolder -childpath "\Templates\ITNTemplate\"
$global:MIDCTemplate=join-path $global:CLEVASourcesFolder -childpath "Templates\MIDCTemplate\"
$global:NewVersionTemplate=join-path $global:CLEVADeploymentPacakges -childpath "Templates\Deployment\"

$global:MDICSQLlogTemplate=@'
@sql/%SCRIPT_NAME%
insert into T_MERC_LOG_PACKAGES (PKG_ID, PKG_TIME, PKG_PACKAGE, PKG_VERSION, PKG_LOG) values (SEQ_T_MERC_LOG_PACKAGES.nextval, sysdate, 'CLEVA', '%CLEVA_VERSION%', '%SCRIPT_NAME%');
'@
}