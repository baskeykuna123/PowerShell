$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"



function WriteJunitXML(){
PARAM($Schema,$StoredProc)
#New-Item -Type Directory -Path "./Reports" -force
#cd Reports

$xmlfile1=[string]::Format("./{0}.xml",$Schema)
$xmlfile=join-path -path ".\Reports" -childpath $xmlfile1 
try{
  Invoke-Sqlcmd -ServerInstance SQL-BE-BIM-SASd -Querytimeout 0 -Query "SET NOCOUNT ON;EXEC TODS_TEST.${Schema}.${StoredProc}" -ErrorAction Stop -Verbose 
} 
catch{
  $sqlerror = $_
  [string]$ErrorMessage=$sqlerror.Exception.InnerException.Message
  if ($ErrorMessage -imatch "package .*") {
    Write-Host "Package did not end run, save XML with error to $xmlfile"
    return ([xml](
@"
<testsuites>
<testsuite id="1" name="$Schema" tests="1" errors="1" failures="0" skipped="0" time="0.0">
<properties />
<testcase classname="$Schema" name="Run the ETL" time="0.0">
<error message="$([Security.SecurityElement]::Escape($ErrorMessage))" />
</testcase>
</testsuite>
</testsuites>
"@)).Save($xmlfile)
  }
  elseif ($ErrorMessage -imatch 'Test Case Summary') {
  }
  else {
    throw $sqlerror
  }
}
Write-Host "Retrieve XML with test results from TODS_TEST.${Schema}.${StoredProc}"
$set = Invoke-Sqlcmd -ServerInstance SQL-BE-BIM-SASd -Querytimeout 0 -Query "SET NOCOUNT ON;EXEC TODS_TEST.tSQLT.XmlResultFormatter" -MaxCharLength $([int]::MaxValue)
Write-Host "Save XML with test results to $xmlfile"

return ([xml]$set.column1).Save($xmlfile)
}

function WriteXML(){
PARAM($Application,$type,$ObjectName,$ObjectSchema,$output)
$ObjectName
$ObjectSchema

$xml = [xml](@"
<?xml version="1.0" encoding="UTF-8"?>  
<Objects>
<Object Name="$ObjectName" Schema="$ObjectSchema" output="$output"/>
</Objects>
"@)

$OutFileName=[string]::Format(".\{0}.xml",$ObjectSchema)
$xml.Save($OutFileName)

}