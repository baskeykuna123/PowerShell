
# Helper function that converts a Baloise list of "add" nodes into JSON ordered keys.
function ConvertNodesFrom-Xml {
  param (
    [parameter(Mandatory)] [XML] $xmlDoc,
    [parameter(Mandatory)] [string] $xmlPath
  )
  foreach ($node in $xmlDoc.SelectNodes($xmlPath))
  {
    # Check if we are testing a secret Key/Value
    if ( ('${' + $node.key + '}') -ne $node.value ) {
      $configDataItems += @{ $node.key = $node.value }
    } else {
      # Make secret value unique to avoid circular reference in Sweagle
      $configDataItems += @{ $node.key = '${SECRET_' + $node.key + '}' }
    }
  }
  Write-Output $configDataItems
}

function ConvertDeploymentParameters4Sweagle{

    param(
        [Parameter(Mandatory)][Alias("file")][string]$argFileIn
    )    

    echo "*** Parsing File $argFileIn";
    $xml = [XML](Get-Content -Path $argFileIn)
    # Not well support in Powershell 6: $xml = Get-Content -Path $argFileIn | ConvertTo-Xml

    echo "*** Parsing the GlobalParameters";
    $configData += @{ GlobalParameters = ConvertNodesFrom-Xml -xmlDoc $xml -xmlPath "//GlobalParameters/add" }

    echo "*** Parsing the Parameters2Exclude";
    $Parameters2Exclude = ConvertNodesFrom-Xml -xmlDoc $xml -xmlPath "//Parameters2Exclude/add"
    if ( $Parameters2Exclude -ne $null ) {
      $configData += @{ Parameters2Exclude = $Parameters2Exclude }
    }

    echo "*** Parsing the EnvironmentParameters";
    $includedEnv=@("dcorp","icorp")
    $configData += @{ EnvironmentParameters = @{ } }
    foreach($env in $xml.SelectNodes("//EnvironmentParameters/Environment"))
    {
      $envName = $env.name
      if ($includedEnv -icontains $envName){
          echo "    *** Parsing the Parameters for Environment $envName";
          #foreach($node in $env.ChildNodes)
          $EnvironmentParameters = ConvertNodesFrom-Xml -xmlDoc $xml -xmlPath "//Environment[@name='$envName']/add"
          $configData.EnvironmentParameters += @{ $envName.ToUpper() = $EnvironmentParameters }
      }
    }

    $json = $configData | ConvertTo-Json

    $fileOut = $argFileIn.Substring(0, $argFileIn.LastIndexOf('.')) + ".json"
    New-Item -ItemType file -Force -Path $fileOut -Value "$json"
    #echo "********** response: $json"

}

function Upload2Sweagle{
    param(
        [String]$paramFileResolved,
        [String]$Application,
        [String]$Buildversion,
        [String]$ScriptDir
    )

    Write-Host "Upload2Sweagle"
    Write-Host "paramFileResolved : "$paramFileResolved
    Write-Host "ScriptDir : "$ScriptDir

    $paramFileResolvedJSon=((get-item $paramFileResolved).FullName).Replace( (get-item $paramFileResolved).Extension, ".json")

    ConvertDeploymentParameters4Sweagle -argFileIn $paramFileResolved
    #$parameters= @{"nodePath"="MyBaloiseWeb"} ==> upload without automatic snapshot
    #$parameters= @{"nodePath"="MyBaloiseWeb"; "storeSnapshotResults"="true" } #==> upload with automatic snapshot
    $parameters= @{"nodePath"="Applications,$($Application)"; "storeSnapshotResults"="true"; "tag"="$($Buildversion)" } 
    $scriptPath = [String]::Format("{0}\Sweagle\SweagleLib.ps1",  $ScriptDir )
    & $scriptPath -operation "upload" -parameters $parameters -filePath $paramFileResolvedJSon -Verbose
}

function ValidateInSweagle{
    param(
        [String]$Application,
        [String]$ScriptDir
    )

    $parameters= @{"cds"="Applications.$($Application)"; "forIncoming"="false";"withCustomValidations"="true" }
    $scriptPath = [String]::Format("{0}\Sweagle\SweagleLib.ps1",  $ScriptDir )
    & $scriptPath -operation "validationStatus" -parameters $parameters -Verbose
}