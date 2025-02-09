$global:ESBRootFolder="E:\Program Files\Mercator\"
$global:EtwToolFolder="E:\Program Files\EtwTool\"
$global:deploymentRootFolder = "E:\Baloise" 
$global:DscModulesRoot="\\balgroupit.com\appl_data\BBE\Transfer\Packages\DscModules"
$global:DfsUserShareRootPath="\\balgroupit.com\appl_data\BBE\User01\"
$global:BackofficeEaiRoot="E:\Mercator.Net\Mercator.EAI\Library\"
$global:EaiDocServiceRoot="E:\Program Files\Mercator\Eai\"
$global:BackofficeRoot="E:\Program Files\Mercator\"
$global:BackofficeServicesRoot="E:\Program Files\Mercator\BOServices\Services\"
$global:BackofficeWebApplicationRoot="E:\Program Files\Mercator\WebFarmServer\WebApplication\"
$global:FrontRoot="E:\Baloise\"
$global:FrontLegacyRoot="E:\Mercator\"
$global:FrontWebsiteRoot="E:\Baloise\WebSite\"
$global:FrontWebApplicationRoot="E:\Baloise\WebApplication\"
$global:PackageRoot="\\Svw-me-pdtalk01\Packages"
$global:MBCPackageRoot="\\balgroupit.com\appl_data\BBE\Packages\MyBaloiseClassic"
$global:NewPackageRoot="\\balgroupit.com\appl_data\BBE\Packages"
$global:LocalPackageRoot="E:\LP"
$global:ReleaseManifest="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\GlobalReleaseManifest.xml"
$global:ReleaseManifestCopy="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\GlobalReleaseManifest - Copy.xml"
$global:CleanupXML="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\Cleanup.xml"
$global:PatchManifest="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\GlobalPatchmanifest.xml"
$global:LoadTestDeploySequencePath="\\shw-me-pdnet01\BuildTeam\Templates\Mercator.Esb.Load.Test.DeploySequence.xml"
$global:TOSCATestExecutionConfig="c:\Program Files (x86)\TRICENTIS\Tosca Testsuite\ToscaCI\Client\CITestExecutionConfiguration.xml"
$global:ToscaCIClientExecutable="c:\Program Files (x86)\TRICENTIS\Tosca Testsuite\ToscaCI\Client\ToscaCIClient.exe"
$global:TOSCATestResultFile="\\svw-be-itrace01\D$\Jenkins\workspace\TOSCA_TestsExecution\Result.xml"
$global:TranferFolderBase="\\balgroupit.com\appl_data\BBE\Transfer\"
$global:ClevaCitrixClientSourcePath="\\balgroupit.com\appl_data\BBE\Transfer\CLEVA\Citrix_OneClient"
$global:MBCCitrixClientSourcePath="\\balgroupit.com\appl_data\BBE\Transfer\MercatorNet\Citrix_OneClient\MercatorNetFiles"
$global:DMSCitrixClientSourcePath="\\balgroupit.com\appl_data\BBE\Transfer\DMS\Citrix_OneClient\IPclientFiles"
$global:DMSCitrixBrandkastSourcePath="\\balgroupit.com\appl_data\BBE\Transfer\DMS\Citrix_OneClient\Brandkast2016"
$global:SharedScriptsBackup="\\balgroupit.com\appl_data\BBE\Transfer\SharedscriptsBackup\"
$global:CDMFolder="E:\Program Files\Mercator\Esb\Portal\Content\Cdm"
$global:PatchManifestRoot="\\balgroupit.com\appl_data\BBE\Packages\Patches\"
$Global:SoapUITestRunner="C:\Program Files\SmartBear\SoapUI-Pro-5.1.2\bin\"
#TFS
$global:TFSServer = "http://TFS-BE:9091/tfs/DefaultCollection"
$global:TFSTestServer = "http://svw-be-tfsp002:9192/tfs/DefaultCollection/Baloise"

#proxysettings
$Global:serverProxy='http://webproxy.balgroupit.com:3038'
# TimeOut
[int]$Global:TimeOut = 60

#CLEVA
$Global:PackageDownloadPath="\\svw-me-pcleva01\d$\Accenture\"
$Global:CLEVAEnvironments="DCORP,ICORP,ACORP,PCORP,PARAM,MIG,MIG4,PRED,EMRG,MIG2"
$Global:ClevaSourcePackages=join-path $global:NewPackageRoot -ChildPath "Cleva\Sources\"
$Global:ClevaReportsFolder=join-path $global:NewPackageRoot -ChildPath "Cleva\Reports\"
$Global:ClevaV14SourcePackages=join-path $global:NewPackageRoot -ChildPath "ClevaV14\Sources\"
$Global:ClevaV14DownloadPackages=join-path $global:NewPackageRoot -ChildPath "ClevaV14\downloads\"
$Global:InjectRDownloadPackages=join-path $global:NewPackageRoot -ChildPath "InjectR\downloads\"
$Global:InjectRSourcePackages=join-path $global:NewPackageRoot -ChildPath "InjectR\Sources\"
$Global:SASLOADERDownloadPackages=join-path $global:NewPackageRoot -ChildPath "SASLOADER\downloads\"
$Global:SASLOADERSourcePackages=join-path $global:NewPackageRoot -ChildPath "SASLOADER\Sources\"

#Build and Release DB info
#$Global:BaloiseBIDBserver="sql-bep1-ps1202\ps1202,30252"
$Global:BaloiseBIDBserver="sql-be-buildp"
$Global:BaloiseCredentialsDatabase="BaloiseCredentials"
$Global:BaloiseReleaseVersionDB="BaloiseReleaseVersions"

#userCreds
$Global:BaloiseVersionDBuserid="L001171"
$Global:BaloiseVersionDBuserpassword="teCH_Key_PRO"
$Global:builduser="prod\builduser"
$Global:builduserPassword="Wetzel01"

#jenkinsUser
$Global:Jenkinsmasteruser="balgroupit\L002867"
$Global:Jenkinsmasterpwd= "76492d1116743f0423413b16050a5345MgB8AC8AZQBUAGcARQBUAEkAeABIAFQASgBEAE4AYwBNAHoANwBJAGcAbwAwAFEAPQA9AHwANABlADUAYQA4ADYAMgA5ADAAMgBkADUAZQBiAGEAZgAzAGYAMwBlADAAZABkADEANAA1ADkAMQBkADYAYgAxADIAMgAzADUAMQBhADUANgAzAGYANgA0ADYAZQAxAGYANgAzADUAOABlADkAOQA1AGYANgBkADIANQBkAGYAZAA="
$Global:secpasswd = $Global:Jenkinsmasterpwd | ConvertTo-SecureString -Key (1..16)
$Global:secureCred = New-Object System.Management.Automation.PSCredential($Global:Jenkinsmasteruser, $Global:secpasswd)


#listInputs
$global:MainFrameAvailablityAppList="ESB,MyBaloiseClassic"
$global:EnvironmentList="DCORP,ICORP,ACORP,PCORP"
$global:TestFarm1Servers="SVW-BE-TSTFI01,SVW-BE-TSTFI02"
$global:TestFarm2Servers="SVW-BE-TSTFI03,SVW-BE-TSTFI04,SVW-BE-TSTFI005,SVW-BE-TSTFI006,SVW-BE-TSTFI007"
$global:EnvironmentStatusApplications="MyBaloiseWeb","CentralDataStore","Backend","Cleva","NINA","Mainframe","MyBaloiseClassic","TALK","EAI","ESB"

#ScriptShareParameteres
$Global:PackageTemplateLocation="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Templates\"
$Global:TestResultsRootPath="\\balgroupit.com\appl_data\BBE\Transfer\Packages\TestResults\"
$Global:NotificationTemplatesRoot="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Notification\Templates\"
$Global:TempNotificationsFolder="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Notifications\TimeStamp\"
$Global:InputParametersPath="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\"
$Global:ScriptSourcePath="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\"
$global:EnvironmentHTMLReportLocation="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Notifications\EnvironmentStautsReports"
$global:Templocation="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Notifications\Temp\"
$global:HTMLTemplateRoot="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Notifications\Templates\"

#globalinputparameterfiles
$Global:EnvironmentXml="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\Environments.xml"
$Global:JenkinsPropertiesRootPath="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\JenkinsParameterProperties\"
$Global:JenkinsBIPropertiesFile="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\JenkinsParameterProperties\BuildandInstall.properties"



#TOSCA
$global:TOSCASchedulerXML="\\balgroupit.com\appl_data\BBE\Transfer\TOSCA_WORKSPACES\TOSCA_Scheduler.xml"
$global:TOSCATestResultsShare="\\balgroupit.com\appl_data\BBE\Packages\Output\TestResults\TOSCA"

#HtmlTemplateFiles
$Global:SOAPUIMailTemplateFile=join-path $ScriptSourcePath  -ChildPath "Notifications\Templates\SOAPUI_TestExecution.html"
$Global:SoapUINinaMailTemplateFile=Join-Path $ScriptSourcePath -ChildPath "Notifications\Templates\SOAPUININA_TestExecution.html"
$Global:EnvironmentStatusTemplate=join-path $ScriptSourcePath  -ChildPath "Notifications\Templates\EnvironmentStatusTest.html" 
$Global:CLEVADBSmokeMailTemplateFile=Join-Path $ScriptSourcePath  -ChildPath "Notifications\Templates\CLEVA_Database_SmokTest.html"

#Toolpaths
$scriptPath = split-path (split-path -parent $MyInvocation.MyCommand.Definition) -parent 
$global:JunctionExePath="$($scriptPath)\Tools\Utilities\Junction.exe"
$global:InstallUtilExePath="$($scriptPath)\Tools\Utilities\InstallUtil.exe"
$global:SQLPackageExe="C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\SqlPackage.exe"
$global:SQLPackage2017Exe="C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\SqlPackage.exe"
$DeploymentwizardExe="C:\Program Files (x86)\Microsoft SQL Server\140\DTS\Binn\ISDeploymentWizard.exe"
$global:WinSCPdllPath=".\Tools\WinSCP\WinSCPnet.dll"
$global:BiztalkOMPath="C:\Program Files (x86)\Microsoft BizTalk Server 2016\Developer Tools\Microsoft.BizTalk.ExplorerOM.dll"

#ServerPaths
$global:ESBPatchTempPath="E:\Program Files\Mercator\Patches\"
$global:ESBDeploymentRootFolder="E:\Program Files\Mercator"

#SharePaths
$global:AppShareRoot="\\balgroupit.com\appl_data\BBE\App01\"
$global:TransferShareRoot="\\balgroupit.com\appl_data\BBE\Transfer\"



#ESB
$Global:InstallutilitiesPath="E:\Program Files\Mercator\InstallationUtilities\Executables\"

#MailLists
$global:JenkinsAdminGroup="shivaji.pai@baloise.be,pankaj.kumarjha@baloise.be,deepak.gorichela@baloise.be"
$global:SOAPUITestExecutionMailList="kenneth.Hauttekeete@baloise.be,sabine.Vereecken@baloise.be,group_be-ict-change-services@baloise.be,pankaj.kumarjha@baloise.be,diederik.de_vos@baloise.be,#BE_BBE_ICT_DELIVERY_AT_CLEVA_INTEGRATION@Baloise.be,#BE_BBE_ICT_DELIVERY_AT_CLEVA_ADMINISTRATION@Baloise.be,#BE_BBE_ICT_COMMUNITY_CLEVA_SYSTEM_TEST@Baloise.be,group_be-ict-at-cleva-policy@baloise.be,danny.huijbrechts@baloise.be"
$global:NiNaSOAPUITestExecutionMailList="sabine.vereecken@baloise.be,danny.huijbrechts@baloise.be"
$global:NINADBDeploymentMail="michael.lewi@baloise.be,stefaan.vangeel@baloise.be,bram.stappaerts@baloise.be,winfried.delanghe@baloise.be,glenn.wyckmans@baloise.be"
$global:CLEVADBDeploymentMail="#BE_BBE_ICT_CLEVA_DEPLOYMENTS@Baloise.be,group_be-ict-at-user-facing-apps@baloise.be,#BE_BBE_ICT_DELIVERY_AT_CLEVA_INTEGRATION@Baloise.be,#BE_BBE_ICT_DELIVERY_AT_CLEVA_ADMINISTRATION@Baloise.be,#BE_BBE_ICT_COMMUNITY_CLEVA_SYSTEM_TEST@Baloise.be"
$global:EnvironmentServiceCheckMail="yves.vanhoye@baloise.be,kenneth.Hauttekeete@baloise.be,gaby.vervoort@baloise.be,uday.turumella@baloise.be,kuna.baskey@baloise.be,deepak.gorichela@baloise.be,tiwari.neha@baloise.be,danny.huijbrechts@baloise.be"
$global:LocalSharesCheckMail="Kurt.Renders@baloise.be,pankaj.kumarjha@baloise.be"
$global:DBFailedMailingList="Kurt.Renders@baloise.be,Shivaji.pai@baloise.be,pankaj.kumarjha@baloise.be,uday.turumella@baloise.be,kuna.baskey@baloise.be,tiwari.neha@baloise.be,deepak.gorichela@baloise.be"
$global:MainframeWatcherMailingList="pankaj.kumarjha@baloise.be,uday.turumella@baloise.be"
$global:TOSCADistributionList="IDL_BBE_Tosca_Mailing@baloise.be"
$global:TOSCAMorningCheckDistributionList="IDL_BBE_Tosca_MorningCheck@baloise.be"
$global:ESBExecutionUserList="pankaj.kumarjha@baloise.be"
$global:NINADeploymentMail="michael.lewi@baloise.be,jozef.brouwers@baloise.be,jan.wilms@baloise.be,daryl.vanloon@baloise.be,nik.torfs@baloise.be"
$global:MWebBrokerDeploymentMail="kurt.renders@baloise.be,ann.vanlangenhove@baloise.be,ann.matheus@baloise.be,gaby.vervoort@baloise.be,Luc.VandeVyver@baloise.be,kenny.lamoot@baloise.be,danny.pollenus@baloise.be,Geert.DeCeuster@baloise.be,Bart.Philips@baloise.be,Philippe.DePesseroy@baloise.be,Els.Pevenage@baloise.be,betty.vanuffelen@baloise.be,anita.reynaerts@baloise.be,tim.meulemeester@baloise.be,leen.vanlancker@baloise.be,serge.vanmoeseke@baloise.be,stefan.thoen@baloise.be,ben.Vroonen@baloise.be,eddy.pynaert@baloise.be,aditi.bhattacharya@baloise.be,group_be-ict-at-user-facing-apps@baloise.be,Kenneth.deroock@baloise.be,jens.reyserhove@baloise.be,deepak.gorichela@baloise.be"
$global:MWebDeploymentMail="kurt.renders@baloise.be,ann.vanlangenhove@baloise.be,ann.matheus@baloise.be,gaby.vervoort@baloise.be,Luc.VandeVyver@baloise.be,kenny.lamoot@baloise.be,danny.pollenus@baloise.be,Geert.DeCeuster@baloise.be,Bart.Philips@baloise.be,Philippe.DePesseroy@baloise.be,Els.Pevenage@baloise.be,betty.vanuffelen@baloise.be,anita.reynaerts@baloise.be,tim.meulemeester@baloise.be,leen.vanlancker@baloise.be,serge.vanmoeseke@baloise.be,stefan.thoen@baloise.be,ben.Vroonen@baloise.be,eddy.pynaert@baloise.be,aditi.bhattacharya@baloise.be,group_be-ict-at-user-facing-apps@baloise.be,Kenneth.deroock@baloise.be,frank.van_bokhoven@baloise.be,jens.reyserhove@baloise.be"
$global:CDSDeploymentMail="pankaj.kumarjha@baloise.be,Kenneth.deroock@baloise.be,deepak.gorichela@baloise.be"
$global:MnetDeploymentMa="pankaj.kumarjha@baloise.be"
$global:BackendDeploymentMail="pankaj.kumarjha@baloise.be,Shivaji.pai@baloise.be,deepak.gorichela@baloise.be"
$global:BICLEVADeploymentMail="pankaj.kumarjha@baloise.be,gaby.vervoort@baloise.be,Uday.turumella@baloise.be,kurt.renders@baloise.be,Shivajisudarshanp@hexaware.com"
$global:ESBDeploymentMail="kurt.renders@baloise.be,pankaj.kumarjha@baloise.be,deepak.gorichela@baloise.be"
$global:EAIDeploymentMail="kurt.renders@baloise.be,pankaj.kumarjha@baloise.be,deepak.gorichela@baloise.be"
$global:BIAdmins="kurt.renders@baloise.be,shivaji.pai@baloise.be,pankaj.kumarjha@baloise.be,deepak.gorichela@baloise.be"
$global:BIDashboardMailRecipients="pankaj.kumarjha@baloise.be,shivaji.pai@baloise.be"
$global:FirecoDeploymentMail="deepak.gorichela@baloise.be,olivier.coudeville@baloise.be"


#Polling and WaitTime
#polling for start and Stop of apps
$Global:ApplicationStartStopPollingSeconds=10
$Global:ApplicationStartStopTimeOutMinutes=new-timespan -Minutes 10

#CLEVA WINSCP SecurityKey file Path
$Global:JenkinsSFTPKey="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Security\20170412-L002618-Public.ppk"

#Deployment Schedules
$Global:CLEVADeploymentSchedule=@{
"PLAB"=23;
"DCORP"=23;
"ICORP"=19;
"ACORP"=19;
}

#WSUS Parameters
$Global:WSUSLogsPath=join-path $Global:ScriptSourcePath -ChildPath "WSUS\Logs\"

#Jenkins Build Pipeline URL
$Global:ESBDCORPDeploymentPipelineUrl="http://Jenkins-be:8080/view/ESB-EAI_Deployments/view/01.DCORP_ESB_Deployment/"
$Global:EaiDcorpDeploymentPipelineUrl="http://Jenkins-be:8080/view/ESB-EAI_Deployments/view/02.DCORP_EAI_Deployment/"
$Global:EsbDcorpbisDeploymentPipelineUrl="http://Jenkins-be:8080/view/ESB-EAI_Deployments/view/03.DCORPBIS_ESB_Deployment/"
$Global:EaiDcorpbisDeploymentPipelineUrl="http://Jenkins-be:8080/view/ESB-EAI_Deployments/view/04.DCORPBIS_EAI_Deployment/"
$Global:EsbIAPDeploymentPipelineUrl="http://Jenkins-be:8080/view/ESB-EAI_Deployments/view/05.IAP_ESB_Deployment/"
$Global:EaiIAPDeploymentPipelineUrl="http://Jenkins-be:8080/view/ESB-EAI_Deployments/view/06.IAP_EAI_Deployment/"

#MyBaloiseClassic
$Global:ClientImageSubPath="MercatorNet\MercatorNetClientImage\"
$Global:LocalMBCWorkFolder="E:\Baloise\MBC_WorkFolder\"