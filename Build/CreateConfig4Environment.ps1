# Enable -Verbose option
[CmdletBinding()]

param([String]$parameterFile, [String]$environment, [String]$packageRootPath, [System.Array]$SearchPattern,[Boolean]$CreateEnvSpecificFile=$true)

#$parameterFile="F:\Packages\DEV_CentralDataStore\20170210.1\CentralDataStoreDeploymentParameters_resolved.xml"
#$environment="PCORP"
#$packageRootPath="F:\Packages\DEV_CentralDataStore\20170210.1"
#$SearchPattern="*.config.deployment"
#$VerbosePreference = "Continue"
#$VerbosePreference = "SilentlyContinue"

if(!$parameterFile){
$parameterFile="E:\LP\Staging_NINA\20201116.5\NINADeploymentParameters_Resolved.xml"
$environment="ICORP"
$packageRootPath="E:\LP\Staging_NINA\20201116.5"
$SearchPattern="NINADeploymentManifest.xml"
}

Write-Verbose "parameterFile = $parameterFile"
Write-Verbose "environment = $environment"
Write-Verbose "packageRootPath = $packageRootPath"
Write-Verbose "SearchPattern = $SearchPattern"

$patternParameters = '\$\{([a-zA-Z0-9_.-]*)\}'
if($parameterFile -ilike "*ESBDeploymentParameter*"){
    $patternParameters = '\%([a-zA-Z0-9_.-]+)\%'
}
$parameters = [xml] (Get-Content $parameterFile)
$MissedParameterListFile=join-path (split-path -path $parameterFile -Parent) -child "MissingParameterslist.txt"

#put all resolved global parameters in a hashtable
$hashtableParameters = @{}
if($parameters.Parameters.GlobalParameters.ChildNodes) {
	$parameters.Parameters.GlobalParameters.ChildNodes | where {$_.NodeType -ne "Comment"} | foreach {$hashtableParameters[$_.key] = $_.value}
}
#put all Parameters2Exclude in a hashtable
$hashtableParameters2Exclude = @{}
if($parameters.Parameters.Parameters2Exclude.ChildNodes) {
	$parameters.Parameters.Parameters2Exclude.ChildNodes | where {$_.NodeType -ne "Comment"} | foreach {$hashtableParameters2Exclude[$_.key] = ""}
}
#add all parameters for the environment
$envrionmentsParametersxpath = [string]::Format("//Parameters/EnvironmentParameters/Environment[@name=""{0}""]",$environment)
$parameters.SelectNodes($envrionmentsParametersxpath).ChildNodes | where {$_.NodeType -ne "Comment"} | foreach {
$_	
$hashtableParameters[$_.key] = $_.value
}
#add EnvironmentName to hashtable
if ( !($hashtableParameters.ContainsKey("EnvironmentName")) ){
    $hashtableParameters["EnvironmentName"] = $environment
}

#loop all files to find/replace
Get-ChildItem $packageRootPath -Recurse -Include $SearchPattern | foreach {
    $newConfigFile=$_.FullName
	if($CreateEnvSpecificFile){
		if ($_.Extension -eq ".deployment") {
			$newConfigFile = Join-Path -Path $_.DirectoryName "$environment.$($_.BaseName)"
		}
		else{
			$newConfigFile = Join-Path -Path $_.DirectoryName "$environment.$($_.Name)"
		}
	}
	
	#$text = (Get-Content $_ -Raw)
$_

	$content = [IO.File]::ReadAllLines($_) 
	foreach ($match in ([regex]$patternParameters).Matches($content )){
$match
		$parameterName = $match.groups[1].Value
        #only do replace if parametername is not in hashtableParameters2Exclude
        if (!$hashtableParameters2Exclude.ContainsKey($parameterName)){
		    if ($hashtableParameters.ContainsKey($parameterName)) {
			    $parameterNotation = $match.groups[0].Value
			    #$content = $content -replace [regex]::Escape($parameterNotation),$hashtableParameters[$parameterName]
                $newValue=$hashtableParameters[$parameterName]
                if ($newValue.Contains("CDATA")){
                    $newValue=$newValue.Split("[").Split("]")[2]
			        $content = $content.replace($parameterNotation,$newValue)
                }
                else{
                    $content = $content.replace($parameterNotation,$newValue)
                }
		    }
		    else{
			    Write-Error "`r`n`r`nPARAM NOT FOUND : $parameterName  IN ENVIRONMENT : $environment`r`n`r`n"
                add-content  $MissedParameterListFile -Value ($_.Name + " | " + $parameterName + " | " + $environment) -Force
		    }
        }
        else{
            #Write-Host "parameterName - $parameterName ignored.."
        }
	}
	
	 $Utf8BomEncoding = New-Object System.Text.UTF8Encoding($True)
	[IO.File]::WriteAllLines($newConfigFile, $content,$Utf8BomEncoding)	
}