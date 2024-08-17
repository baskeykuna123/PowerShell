# Enable -Verbose option
[CmdletBinding()]

param([String]$parameterFile, [String]$BuildVersion)

#loading Utilities
#. "$PSScriptRoot\fnUtilities.ps1"

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 
if(!$parameterFile){
$parameterFile="\\svw-me-pdtalk01\f$\Packages\Staging_NINA\20171031.5\NINADeploymentParameters.xml"
$BuildVersion="Staging_NINA_20171031.5"
$environment="ICORP"
$VerbosePreference = "Continue"
$VerbosePreference = "SilentlyContinue"
}

Write-Verbose "parameterFile = $parameterFile"
Write-Verbose "BuildVersion = $BuildVersion"

function Resolve
{
	param (
		[String] $xPath, 
		[String] $environment=[String]::Empty,
		$ExcludedParameters		
	)
	
	$loopCount = 0
	$Errors = @{}
	Do{
		$parameters.SelectSingleNode($xPath).ChildNodes | where {$_.NodeType -ne "Comment"} | foreach {
			if ( ([regex]$patternParameters).Match($_.value).Success) {
				$parameterName = ([regex]$patternParameters).Match($_.value).groups[1].Value
				if (!$ExcludedParameters.ContainsKey($parameterName)){         
				$xPathSingleNode = [string]::Format("{0}/add[@key=""{1}""]",$xPath,$parameterName)
				$parameterValue=$parameters.SelectNodes($xPathSingleNode).Value
				If ($parameterName -ieq "EnvironmentName"){
					$parameterValue = $environment
				}
				elseif ($parameterName -like "*ApplicationVersion"){
					$parameterValue = $BuildVersion
				}
				elseif ($parameterValue -eq "`${$($parameterName)}"){
					$parameterValue=get-Credentials -Environment $environment  -ParameterName  $parameterName
				}
				else{	
					$parameterValue = $parameters.SelectNodes($xPathSingleNode).Value
				}
				
				#add error hashtable if parametervalue was not found
				if ($parameterValue){
					$_.value =  $_.value.Replace(([regex]$patternParameters).Match($_.value).groups[0].Value,$parameterValue)
				}
				else {
					$Errors["Parameter ""$parameterName"" not declared in $xPath"]=""
				}
			  }
			}
		}
		$loopCount++
	}
	Until ($loopCount -ge 10)
	
	#write errors
	$Errors.Keys | foreach {
		Write-Error $_
	}
}

$patternParameters = '\$\{(.+?)\}'
if($parameterFile -ilike "*ESB*"){
	$patternParameters = '\%(.+?)\%'	
}

$parameters = [xml] (Get-Content Filesystem::$parameterFile)
$parameterFileObject=Get-Item Filesystem::$parameterFile
$parameterFileNew = [String]::Format("{0}\{1}_Resolved{2}", $parameterFileObject.DirectoryName, $parameterFileObject.BaseName, $parameterFileObject.Extension)

#Excluded param list
$hashtableParameters2Exclude = @{}
if($parameters.Parameters.Parameters2Exclude.ChildNodes) {
	$parameters.Parameters.Parameters2Exclude.ChildNodes | where {$_.NodeType -ne "Comment"} | foreach {$hashtableParameters2Exclude[$_.key] = ""}
}
$hashtableParameters2Exclude
#first resolve global parameters 
Resolve -xPath "//Parameters/GlobalParameters" -ExcludedParameters $hashtableParameters2Exclude

#put all resolved global parameters in a hashtable
$globalParameters = @{}
$envrionmentsParametersxpath = "//Parameters/EnvironmentParameters/Environment"
if($parameters.Parameters.GlobalParameters.ChildNodes) {
	$parameters.Parameters.GlobalParameters.ChildNodes | where {$_.NodeType -ne "Comment"} |foreach {$globalParameters[$_.key] = $_.value}
$globalParameters
	#loop EnvironmentParameters and resolve all global parameters - skip the comment nodes

	$parameters.SelectNodes($envrionmentsParametersxpath).ChildNodes | where {$_.NodeType -ne "Comment"} | foreach {
		foreach ($match in ([regex]$patternParameters).Matches($_.value)) {		
			$parameterName = $match.groups[1].Value
			if ($globalParameters.ContainsKey($parameterName)) {
				$_.value =  $_.value.Replace($match.groups[0].Value, $globalParameters.Item($parameterName) )
			}
		}
	}
}
#loop all Environments and resolve all envirommnet parameters - skip the comment nodes
$parameters.SelectNodes($envrionmentsParametersxpath) | where {$_.NodeType -ne "Comment"} | foreach {
	$currentEnvironment = $_.Attributes.GetNamedItem("name").Value
	Resolve -xPath "//Parameters/EnvironmentParameters/Environment[@name=""$currentEnvironment""]" -environment $currentEnvironment -ExcludedParameters $hashtableParameters2Exclude
}

$parameters.Save($parameterFileNew)
