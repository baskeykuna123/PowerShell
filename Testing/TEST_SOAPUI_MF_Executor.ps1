PARAM($Environment,$JenkinsReportPath)

Clear-Host

if(!$Environment){
	$Environment="ACORP"
	$JenkinsReportPath="D:\test\"
}

#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#$SOAPUIbinPath="C:\Program Files (x86)\eviware\soapUI-3.0\bin"
$SOAPUIbinPath="C:\Program Files\SmartBear\SoapUI-Pro-5.1.2\bin"
$SOAPUIProjectXML=[string]::Format("Readiness Test {0}-{1} NEW-soapui-project.xml",$Environment.Substring(0,1),$Environment.Substring(1,$Environment.Length-1))
$TestScriptSourcePath=join-path "D:\Delivery\Deploy\readiness\xml\" -ChildPath $SOAPUIProjectXML
$SOAPUIbinPath
$command=[string]::Format("testrunner.bat `"{1}`" -j -r -f{3} -a",$SOAPUIbinPath,$TestScriptSourcePath,$Environment,$JenkinsReportPath)
if($TestScriptSourcePath){
	Write-Host "==================================================================================="
	Write-Host "SOAPUI ProjectFile   :" $SOAPUIProjectXML
	Write-Host "SOAPUI Commmand      :" $command
	Write-Host "Report path          :" $JenkinsReportPath
	Write-Host "==================================================================================="
    cmd /c $command
}
else{
	Write-Host "$($TestScriptSourcePath)  is invalid... Aborting"
	Exit 1
}


$ReportSource=(get-childitem $JenkinsReportPath -Filter "TEST-$($Environment)_*.xml").FullName | select
#Preparing HTML content for Mail and Environment Status
$TestResultsHTML="<TABLE class='rounded-corner'>"
$TestResultsHTML+="<TR align=center><TH colspan='4'>Mainframe Check Details: $($Environment)</TH></TR>"
$TestResultsHTML+="<TR><TH><B>Test Suite</B></TH><TH><B>Total</B></TH><TH><B>Failed</B></TH><TH><B>ExecutionTime</B></TH>"
#Reading the Test results file to convert to HTML 
$data=[xml] (Get-Content $($ReportSource))
$data.testsuite | foreach {
	$TestResultsHTML+=[string]::Format("<TR><TD><B>{0}</B></TD><TD>{1}</TD><TD>{2}</TD><TD>{3}</TD></TR>",$($_.name),$($_.tests),$($_.failures),$($_.time))
}
$TestResultsHTML+="</TABLE>"

$EnvironmentStatusHTM = [string]::Format("{0}\{1}_Mainframe_Check.htm",$global:EnvironmentHTMLReportLocation,$Environment)
$HtmlBodyStatus = [system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\EnvironmentStatusTest.html" ))
$Timestamp = Get-Date
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#DateTime#",(Get-Date)
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#StatusReport#",$TestResultsHTML
$HtmlBodyStatus | Out-File Filesystem::$EnvironmentStatusHTM -Force