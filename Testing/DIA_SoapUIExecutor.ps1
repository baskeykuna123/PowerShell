param($repositoryName,$soapUIProjectFolder,$Environment,$soapUIProjectName,$testSuite)

#Loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$TestReportLocation="$env:WORKSPACE"
$SoapUIProjectXMLRoot=[String]::Format("{0}\{1}\{2}",$env:WORKSPACE,$repositoryName,$soapUIProjectFolder)
$cmd = [String]::Format("testrunner.bat -s{0} -j -f{1} -o -R""JUnit-Style HTML Report"" -E{2} -GTimeStamp -G= -G""2020-08-31T -G10:12:12.222Z"" {3}\{4}",$testSuite,$TestReportLocation,$Environment,$SoapUIProjectXMLRoot,$soapUIProjectName)
Write-host "Command to be executed:"$cmd
cmd.exe /c $cmd | Write-Host