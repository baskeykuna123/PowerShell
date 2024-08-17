PARAM(
	[string]$BuildDatabaseName,
	[string]$BuildNumber,
	[string]$Environment="dcorp",
    [string]$EsbOrEai="Esb"
	)

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


if (!$BuildDatabaseName){
    $BuildDatabaseName="MercatorBuild.4.29"
    $BuildNumber="33.4.20200803.150134"
    $Environment="dcorp"
    $EsbOrEai="ESB"
}

clear

#Temp Source path needs to be changed. the E:\EsbPackages refers to BLDP001 Server where the Pacakges are ready
if($EsbOrEai -ieq "Esb"){
    $BuildOutputPath="e:\P.ESB"
    $ApplicationName="MercatorESB"
}
else{
    $BuildOutputPath="e:\P.EAI"
    $ApplicationName="MercatorEAI"
}

if ( ($Environment -ieq "dcorp") -or ($Environment -ieq "dcorpbis") ) {
    $Environments2Configure=@("dcorp","dcorpbis")
}
else{
    $Environments2Configure=@("icorp","acorp","pcorp")
}


#Script Paths for ConfigGeneration and Resolving parameters
$ResolveParametersScriptPath=join-path $ScriptDirectory -ChildPath "\build\ResolveParameterXml.ps1"
$Config4EnvironmentScriptPath=join-path $ScriptDirectory -ChildPath "\build\CreateConfig4Environment.ps1"

#Variables
$EnvironmentExclusionlist="DomainParameterName","prod","playground","MCORP","MCORP4","MCORP2"
$ConfigFileextensions = "*.xml","*.config","*.sql","*.cmd"
$PackageSource=Join-Path $BuildOutputPath -ChildPath $BuildNumber
$ParmeterXMLpath=Join-Path $PackageSource -ChildPath "ESBDeploymentParameters.xml"

#Creating PS Drive to overcome 265 charcater issue
New-PSDrive -Name K -PSProvider Filesystem -Root $PackageSource

#The template to for Paramter XML
[xml]$ParamXML=@'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<Parameters>
	<!-- Global parameters can be nested in the value of global parameters and in the value of Environment parameters-->  
	<GlobalParameters>
	</GlobalParameters>
    <!-- Parameters2Exclude are defined for parameters which are used by an application itself eg BizTalk - eg MessageID in BizTalk bindingfiles-->  
    <Parameters2Exclude>
    </Parameters2Exclude>
	<EnvironmentParameters>
	</EnvironmentParameters>
</Parameters>
'@

#Read GlobalReleaseManifest.xml
$xmlReleaseManifest=[xml](Get-Content Filesystem::$global:ReleaseManifest)

#Extracting the Parameters from the build database
$selectQuery="select * from String2Parameter ORDER BY Sequence"
$String2Parameters=(Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $BuildDatabaseName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out)

$selectQuery="select * from commonparameters"
$CommonParameters=(Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $BuildDatabaseName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out)

$selectQuery="select * from domainparameters"
$DomainParameters=(Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $BuildDatabaseName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out)

$selectQuery="select * from Parameters2Exclude"
$Parameters2Exclude=(Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $BuildDatabaseName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out)

$selectQuery="Select * from ExcludeApplicationsOnEnvironments"
$ExcludeApplicationsOnEnvironments=(Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $BuildDatabaseName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out)

#setting the Environmentlist based on domain parameters and Exlusion list
$Environments=([system.data.datarow]$DomainParameters[0]).Table.Columns.ColumnName | Where-Object { $EnvironmentExclusionlist  -notcontains $_ }

#preaparing the Parameter XML
#Creating Environment Sections
foreach($Environment in $Environments){
		$EnvironmentParams=$ParamXML.SelectSingleNode("//Parameters/EnvironmentParameters")
		$new=$ParamXML.CreateElement("Environment")
		$new.SetAttribute("name",$Environment)
		$EnvironmentParams.AppendChild($new) | Out-Null
}
#Creating Globalparameters
foreach($param in $CommonParameters) {
	$row=[system.data.datarow]$param
		$EnvironmentParams=$ParamXML.SelectSingleNode("//Parameters/GlobalParameters")
		$new=$ParamXML.CreateElement("add")
		$new.SetAttribute("key",$row[0])
		$new.SetAttribute("value",$row[1])
		$EnvironmentParams.AppendChild($new) | Out-Null
}
#Creating Parameters2Exclude
foreach($param in $Parameters2Exclude) {
	$row=[system.data.datarow]$param
		$EnvironmentParams=$ParamXML.SelectSingleNode("//Parameters/Parameters2Exclude")
		$new=$ParamXML.CreateElement("add")
		$new.SetAttribute("key",$row[0])
		$EnvironmentParams.AppendChild($new) | Out-Null
}
#add parameters from GlobalReleaseManifest
foreach($Environment in $Environments){
	$EnvironmentParams=$ParamXML.SelectSingleNode("//Parameters/EnvironmentParameters/Environment[@name='$Environment']")
    $EnvUpperCase=$Environment.ToUpper()	
    #Add MercatorFrameworkVersion
    $new=$ParamXML.CreateElement("add")    
    $applicationNode=$xmlReleaseManifest.SelectSingleNode("//Release/environment[@Name='$EnvUpperCase']/Application[@Name='$ApplicationName']")
	$new.SetAttribute("key","MercatorFrameworkVersion")
	$new.SetAttribute("value",$applicationNode.MercatorFrameworkVersion)
	$EnvironmentParams.AppendChild($new) | Out-Null
    #Add Branch
    $new=$ParamXML.CreateElement("add")    
	$new.SetAttribute("key","Branch")
	$new.SetAttribute("value",$applicationNode.TFSBranch)
	$EnvironmentParams.AppendChild($new) | Out-Null
}
#creating Domain Specific parameters
foreach($param in $DomainParameters) {
	foreach($Environment in $Environments){
		$row=[system.data.datarow]$param
		$EnvironmentParams=$ParamXML.SelectSingleNode("//Parameters/EnvironmentParameters/Environment[@name='$Environment']")
		$new=$ParamXML.CreateElement("add")
		$new.SetAttribute("key",$row[0])
		$new.SetAttribute("value",$row[$Environment])
		$EnvironmentParams.AppendChild($new) | Out-Null
	}
}

#add environment specific applications that are to be excluded
$ExcludeEnvironments=$($ExcludeApplicationsOnEnvironments.Environment)
foreach($Environment in $Environments){
       if ($ExcludeEnvironments -icontains $Environment){
            $ApplicationtoExlude = $($ExcludeApplicationsOnEnvironments |?{$_.Environment -ieq "$Environment"} | Select ApplicationName).ApplicationName
		    $EnvironmentParams=$ParamXML.SelectSingleNode("//Parameters/EnvironmentParameters/Environment[@name='$Environment']")
		    $new=$ParamXML.CreateElement("add")
		    $new.SetAttribute("key","ApplicationToExclude")
		    $new.SetAttribute("value",$ApplicationtoExlude)
		    $EnvironmentParams.AppendChild($new) | Out-Null
      }
}

$ParamXML.Save($ParmeterXMLpath)


#Resolving Nested Parameters
& $ResolveParametersScriptPath -parameterFile $ParmeterXMLpath -BuildVersion $BuildNumber
$parameterFileResolved=[string](get-childitem -path "K:\" -Force -Recurse -Filter "*_Resolved.xml" -ErrorAction Ignore).FullName


#Creating Template files from Configs,XMLs, Sqls,etc
$FolderExlusions=@("*\Packages\*","*\RES\*","*\SCHEMA\*")
$FileExclusions=@("*ESBDeploymentParameters*.xml")
$allowedFileCount=$totalCount=0

Get-ChildItem -path "K:\" -Force -Recurse -Include $ConfigFileextensions -file |  foreach {
    $allowedFolder=$true
    $allowedfile=$true
    $totalCount++
    foreach($folder in $FolderExlusions){
	    if($_.FullName -ilike $folder){
	        $allowedFolder=$false
	        break;
	    }

	}
    foreach($file in $FileExclusions){
        if($_.Name -ilike $file){
			$allowedfile=$false
            break;
		}
	}
    if($allowedFolder -and $allowedfile){
        $allowedFileCount++
        $file=$_
        $TemplatefilePath=join-path (Split-Path $file -Parent) -ChildPath ($file.Name + ".deployment")
        $Content=Get-Content -Path $file.FullName
        foreach($str in $String2Parameters){
            $replacetext=[Regex]::Unescape($str.ParameterName)
            $Content=$Content -ireplace $str.String,$replacetext
        }
    
        $Utf8BomEncoding = New-Object System.Text.UTF8Encoding($True)
	    #Set-Content $TemplatefilePath -Value $Content -Encoding $Utf8BomEncoding
         
        [System.IO.File]::WriteAllLines($TemplatefilePath,$Content,$Utf8BomEncoding)
		if($file.Extension -ieq ".sql"){
			Remove-Item $file.FullName -Force -Recurse
		}
    }
}

write-host "Total Files Parsed     : " $totalCount
write-host "Template files Created : " $allowedFileCount
$Extensions=@("*.sql","*.xml","*.config","*.deployment")
#generating Config files based on Environments 
foreach($Environment in $Environments2Configure){
foreach($searchpattern in $Extensions){
	& $Config4EnvironmentScriptPath -verbose -parameterFile $parameterFileResolved -environment $environment -packageRootPath "K:\" -SearchPattern $searchpattern
}
}
Remove-PSDrive -name K -Force 
