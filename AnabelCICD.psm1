function Test-SqlDeploy {
  Param (
    [Parameter(Mandatory=$true)]
    [String]
    $Database, 
    [Parameter(Mandatory=$true)]
    [String]
    $Environment, 
    [Parameter(Mandatory=$true)]
    [String]
    $OutPath
  )
  Write-DefaultJunitXml $([System.IO.Path]::Combine($OutPath, "TestSqlDeploy${Database}${Environment}.xml"))
}

function Test-SsisDeploy {
  Param (
    [Parameter(Mandatory=$true)]
    [String]
    $Database, 
    [Parameter(Mandatory=$true)]
    [String]
    $Environment, 
    [Parameter(Mandatory=$true)]
    [String]
    $OutPath
  )
  Write-DefaultJunitXml $([System.IO.Path]::Combine($OutPath, "TestSsisDeploy${Database}${Environment}.xml"))
}

function Test-Ssis  {
  Param (
    [Parameter(Mandatory=$true)]
    [String]
    $Database, 
    [Parameter(Mandatory=$true)]
    [String]
    $OutPath
  )
  Write-DefaultJunitXml $([System.IO.Path]::Combine($OutPath, "TestSsis${Database}.xml"))
}

function Test-Sql  {
  Param (
    [Parameter(Mandatory=$false)]
    [String]
    $Database, 
    [Parameter(Mandatory=$true)]
    [String]
    $OutPath
  )
  Write-DefaultJunitXml $([System.IO.Path]::Combine($OutPath, "TestSql${Database}.xml"))
}

function Write-DefaultJunitXml(
  $OutFileName
) {
  $xml = [xml](@'
  <testsuites />
'@)
	# save xml to file
	Write-Host "Path" $OutFileName
	$xml.Save($OutFileName)
}

function Write-JunitXml(
  [System.Collections.ArrayList] $Results
  , [System.Collections.HashTable] $HeaderData
  , [System.Collections.HashTable] $Statistics
  , $ResultFilePath) {
$template = @'
<testsuite name="" file="">
<testcase classname="" name="" time="">
	<failure type=""></failure>
</testcase>
</testsuite>
'@
	
	$guid = [System.Guid]::NewGuid().ToString("N")
	$templatePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $guid + ".txt");
	
	$template | Out-File $templatePath -encoding UTF8
	# load template into XML object
	$xml = New-Object xml
	$xml.Load($templatePath)
	# grab template user
	$newTestCaseTemplate = (@($xml.testsuite.testcase)[0]).Clone()	
	
	$className = [System.IO.Path]::GetFileNameWithoutExtension($HeaderData.TestFileName)
	$xml.testsuite.name = $className
	$xml.testsuite.file = $HeaderData.TestFileName
	
	foreach($result in $Results) 
	{   
		$newTestCase = $newTestCaseTemplate.clone()
		$newTestCase.classname = $className
		$newTestCase.name = $result.Test.ToString()
		$newTestCase.time = $result.Time.ToString()
		if($result.Result -eq "PASS")
		{	#Remove the failure node
			$newTestCase.RemoveChild($newTestCase.ChildNodes[0]) | Out-Null
		}
		else
		{
			$newTestCase.failure.InnerText = Format-ErrorRecord $result.Reason
		}
		$xml.testsuite.AppendChild($newTestCase) > $null
	}   

	# remove users with undefined name (remove template)
	$xml.testsuite.testcase | Where-Object { $_.Name -eq "" } | ForEach-Object  { [void]$xml.testsuite.RemoveChild($_) }
	# save xml to file
	Write-Host "Path" $ResultFilePath
	
	$xml.Save($ResultFilePath)
	
	Remove-Item $templatePath #clean up
}