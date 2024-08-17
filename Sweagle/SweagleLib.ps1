# This powershell script handles the most used Sweagle APIs which are
#  - info (to test connectivity)
#  - upload
#  - validate/validationStatus
#  - snapshot
#  - export
# Version 1.1
# Author : Dimitris Finas
# Inputs required: 1- operation (see API list above) and 2- parameters (hasmap of key/values arguments used for the API called)

param(
    [Parameter(Mandatory=$true)][Alias("op")][ValidateSet('info','upload','validate','validationStatus','snapshot','export')][string]$operation,
    [Parameter(Mandatory=$false)][Alias("args")][hashtable]$parameters,
    [Parameter(Mandatory=$false)][Alias("file")][string]$filePath
)


# Force execution policy to allow Remote script to run
# Use UNRESTRICTED if you should run this script remotely
#try {
    #Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy UNRESTRICTED
#} catch {
    #Write-Warning -Message "*** WARNING: Execution policy is not supported, ignore it"
#}
###########################################
#  DEFAULT VARIABLES
###########################################
# This is file containing Sweagle Tenant access parameters
$dbFile="$PSScriptRoot\db.json"
$defaultExporter="all"
$defaultFormat="json"
$defaultAutoApprove="true"

###########################################
#  HELPER FUNCTIONS
###########################################

# Call Sweagle API with common error handling
function callSweagleAPI {
    param (
        [Parameter(Mandatory=$true)][string]$apiPath,
        [Parameter(Mandatory=$false)][hashtable]$parameters,
        [Parameter(Mandatory=$false)][string]$apiMethod = "POST",
        [Parameter(Mandatory=$false)][string]$filePath
    )

    # Read SWEAGLE Connection parmaeters from db.JSON
    if (!(Test-path $dbFile)) {
        Write-Warning -Message "********** ERROR: Cannot find SWEAGLE params file ($dbFile)";
        exit 1
    }
    $sweagleParams = Get-Content $dbFile | ConvertFrom-Json

    # Add parameters if present
    $args = ""
    if ($PSBoundParameters.ContainsKey('parameters')) {
        Write-Verbose -Message "*** USE API PARAMETERS $parameters"
        #$argNodePath = $argNodePath -replace '/', ','
        If ($parameters.ContainsKey('format'))
        {
            Write-Verbose -Message "*** Use format parameter to define content-type"
            $format = $parameters["format"].ToLower()
            switch ($format)
            {
                "ini"  { $contentType = "text/plain" }
                "json" { $contentType = "application/json" }
                "yaml" { $contentType = "application/x-yaml" }
                "yml"  { $contentType = "application/x-yaml" }
                "xml"  { $contentType = "application/xml" }
                default { $contentType = "text/x-java-properties" }
            }
        } else {
            $contentType = "text/plain"
        }

        Write-Verbose -Message "*** Add parameters to API URL"
        $first = $true;
        foreach ($parameter in $parameters.GetEnumerator()) {
            # Name = Key
            Write-Verbose -Message "*** ADD PARAMETER $($parameter.Name)=$($parameter.Value)"
            if ($first) {
                $args = "?$($parameter.Name)=$($parameter.Value)"
                $first = $false
            } else {
                $args = $args+"&$($parameter.Name)=$($parameter.Value)"
            }
        }
    }

    try {
        $url = [uri]::EscapeUriString($sweagleParams.environment.url + $apiPath + $args)
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Bearer " + $sweagleParams.user.token)
        $headers.Add("Accept", "*/*")

        if ($sweagleParams.environment.host -And $sweagleParams.environment.host -ne "") {
            $proxyUri = "http://" + $sweagleParams.environment.host + ":" + $sweagleParams.environment.port
            Write-Verbose -Message "*** DETECTED PROXY $proxyUri"
            if ($sweagleParams.environment.proxyName -And $sweagleParams.environment.proxyName -ne "") {
                $username = $sweagleParams.environment.proxyName;
                Write-Verbose -Message "*** DETECTED PROXY USER $username"
                $passwordString = $sweagleParams.environment.proxyKey
                $password = ConvertTo-SecureString -String $passwordString -AsPlainText -Force
                $credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $username, $password


                $AzAccountName="balgroupit\L002867"
                $AzSecurePwd= "76492d1116743f0423413b16050a5345MgB8AC8AZQBUAGcARQBUAEkAeABIAFQASgBEAE4AYwBNAHoANwBJAGcAbwAwAFEAPQA9AHwANABlADUAYQA4ADYAMgA5ADAAMgBkADUAZQBiAGEAZgAzAGYAMwBlADAAZABkADEANAA1ADkAMQBkADYAYgAxADIAMgAzADUAMQBhADUANgAzAGYANgA0ADYAZQAxAGYANgAzADUAOABlADkAOQA1AGYANgBkADIANQBkAGYAZAA="
                $secpasswd = $AzSecurePwd | ConvertTo-SecureString -Key (1..16)
                $credential = New-Object System.Management.Automation.PSCredential ($AzAccountName, $secpasswd)

                [system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('http://webproxy.balgroupit.com:3038', $true) 
                [system.net.webrequest]::defaultwebproxy.credentials = $credential
                [system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true
                [System.Net.ServicePointManager]::SecurityProtocol= [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'

                #$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))
                #$headers.Add("Proxy-Authorization", "Basic $base64AuthInfo")

                #$response = Invoke-RestMethod -Uri "https://baloise.sweagle.com/info" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Proxy $proxyUri -ProxyCredential $credential -Method GET -Verbose
                if ($PSBoundParameters.ContainsKey('filePath')) { 
                    #$response = Invoke-RestMethod -Uri $url -Headers $headers -InFile $filePath -ContentType $contentType -Proxy $proxyUri -ProxyCredential $credential -Method $apiMethod 
                    $response = Invoke-RestMethod -Uri $url -Headers $headers -InFile $filePath -ContentType $contentType -Method $apiMethod 
                }
                else { 
                    #$response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType $contentType -Proxy $proxyUri -ProxyCredential $credential -Method $apiMethod 
                    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType $contentType -Method $apiMethod 
                }
            } else {
                Write-Verbose -Message "*** NO PROXY USER"
                if ($PSBoundParameters.ContainsKey('filePath')) { $response = Invoke-RestMethod -Uri $url -Headers $headers -InFile $filePath -ContentType $contentType -Proxy $proxyUri -ProxyUseDefaultCredentials -Method $apiMethod }
                else { $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType $contentType -Proxy $proxyUri -ProxyUseDefaultCredentials -Method $apiMethod }
            }
        } else {
            Write-Verbose -Message "*** NO PROXY"
            if ($PSBoundParameters.ContainsKey('filePath')) { $response = Invoke-RestMethod -Uri $url -Headers $headers -InFile $filePath -ContentType $contentType -Method $apiMethod }
            else {$response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType $contentType -Method $apiMethod }
        }
    } catch {
        #Write-Error -Message "HTTP StatusCode: $_.Exception.Response.StatusCode.value__"
        Write-Error -Message "********** ERROR: API call failed. Exception: $_"
        exit 1
    }

    $responseJson = $response | ConvertTo-Json
    Write-Output $responseJson
    #echo "********** API response: $responseJson"

}

###########################################
#  API FUNCTIONS
###########################################

function export {
    param (
        [Parameter(Mandatory=$true)][hashtable]$parameters,
        [Parameter(Mandatory=$false)][string]$filePath
    )
    # Allowed parameters
    #arg=${arg:-}
    #cds=${cds:-}
    #mdsArgs=${mdsArgs:-}
    #mdsTags=${mdsTags:-}
    #parser=${parser:-}
    #tag=${tag:-}

    $apiPath = "/api/v1/tenant/metadata-parser/parse";

    # Checking input parameters
    if (-Not ($parameters.ContainsKey('cds'))) {
        Write-Error -Message "********** ERROR: cds (name of Configuration Data Set) parameter is required !"; exit 1
    } else {
        # Replace cds argument by mds as it is expected by API
        $parameters.Add("mds", $parameters["cds"])
        $parameters.Remove("cds")
    }
    if (-Not ($parameters.ContainsKey('parser'))) {
        Write-Warning -Message "*** WARNING: Parser (export rule to use) parameter is not defined, will use default '$defaultExporter'"
        $parameters.Add("parser", $defaultExporter)
    }
    if (-Not ($parameters.ContainsKey('format'))) {
        Write-Warning -Message "*** WARNING: format parameter is not defined, will use default '$defaultFormat'"
        $parameters.Add("format", $defaultFormat)
    }

    # Call Sweagle API
    $response = callSweagleAPI -apiPath $apiPath -parameters $parameters
    # If file provided then store to file else display response
    If ($PSBoundParameters.ContainsKey('filePath') -And $filePath -ne "") {
        Write-Verbose -Message "*** Write result to file $filePath"
        New-Item -ItemType file -Force -Path $filePath -Value "$response"
    } else { Write-Output $response }
}

function getInfo {
    $response = callSweagleAPI -apiPath "/info" -apiMethod "GET"
    Write-Output $response
}

function snapshot {
    param (
        [Parameter(Mandatory=$true)][hashtable]$parameters
    )
    # Allowed parameters
    #cds=${cds:-}
    #tag=${tag:-}
    #description=${description:-}
    #level=${level:error or warn}

    $apiPath = "/api/v1/data/include/snapshot/byname"

    Write-Verbose -Message "*** Check input parameters $parameters"
    if (-Not ($parameters.ContainsKey('cds'))) {
        Write-Error -Message "********** ERROR: cds (name of Configuration Data Set) parameter is required !"; exit 1
    } else {
        # Replace cds argument by name as it is expected by API
        $parameters.Add("name", $parameters["cds"])
        $parameters.Remove("cds")
    }

    $response = callSweagleAPI -apiPath $apiPath -parameters $parameters
    Write-Output $response
}

function upload {
    param (
        [Parameter(Mandatory=$true)][string]$filePath,
        [Parameter(Mandatory=$true)][hashtable]$parameters
    )
    # Set API arguments default values
    #allowDelete=${allowDelete:-false}
    #autoApprove=${autoApprove:-true}
    #autoRecognize=${autoRecognize:-false}
    #changeset=${changeset:-}
    #description=${description:-}
    #filePath=${file:-}
    #encoding=${encoding:-utf-8}
    #identifierWords=${identifierWords:-}
    #nodePath=${nodePath:-}
    #onlyParent=${onlyParent:-true}
    #runRecognition=${runRecognition:-false}
    #storeSnapshotResults=${storeSnapshotResults:-false}
    #tag=${tag:-}
    #validationLevel=${validationLevel:-"warn"} # Possible values validOnly | warn | error

    $apiPath = "/api/v1/data/bulk-operations/dataLoader/upload"

    Write-Verbose -Message "*** Check input parameters $parameters"
    Write-Verbose -Message "*** USE INPUT FILE $filePath"
    if (!(Test-path $filePath)) {
        Write-Error -Message "********** ERROR: File $filePath doesn't exist !";
        exit 1
    }
    if (-Not ($parameters.ContainsKey('nodePath'))) { Write-Error -Message "********** ERROR: nodePath parameter is required !"; exit 1 }
    if (-Not ($parameters.ContainsKey('autoApprove'))) {
        Write-Warning -Message "*** WARNING: autoApprove parameter is not defined, will use default '$defaultAutoApprove'"
        $parameters.Add("autoApprove", $defaultAutoApprove)
    }
    if (-Not ($parameters.ContainsKey('format'))) {
        Write-Verbose -Message  "*** Define config format based on file extension"
        $extension = [System.IO.Path]::GetExtension($filePath)
        switch ( $extension.ToLower() )
        {
            ".ini"  { $parameters.Add("format", "ini") }
            ".json" { $parameters.Add("format", "json") }
            ".yaml" { $parameters.Add("format", "yaml") }
            ".yml"  { $parameters.Add("format", "yaml") }
            ".xml"  { $parameters.Add("format", "xml") }
            default { $parameters.Add("format", "props") }
        }
        $format = $parameters["format"]
        Write-Verbose -Message "File extension detected is: $format"
    }
#exit 0
    # Call Sweagle API
    $response = callSweagleAPI -apiPath $apiPath -parameters $parameters -filePath $filePath
    Write-Output $response
}

function validate {
    param (
        [Parameter(Mandatory=$true)][hashtable]$parameters
    )
    # Allowed parameters
    #arg=${arg:-}
    #cds=${cds:-}
    #forIncoming=${forIncoming:-true}
    #mdsArgs=${mdsArgs:-}
    #mdsTags=${mdsTags:-}
    #parser=${parser:-}

    $apiPath = "/api/v1/tenant/metadata-parser/validate"

    Write-Verbose -Message "*** Check input parameters $parameters"
    if (-Not ($parameters.ContainsKey('cds'))) {
        Write-Error -Message "********** ERROR: cds (name of Configuration Data Set) parameter is required !"; exit 1
    } else {
        # Replace cds argument by mds as it is expected by API
        $parameters.Add("mds", $parameters["cds"])
        $parameters.Remove("cds")
    }

if (-Not ($parameters.ContainsKey('parser'))) { Write-Error -Message "********** ERROR: parser (validator to use) parameter is required !"; exit 1 }

    $response = callSweagleAPI -apiPath $apiPath -parameters $parameters
    Write-Output $response
}

function validationStatus {
    param (
        [Parameter(Mandatory=$true)][hashtable]$parameters
    )
    # Allowed parameters
    #cds=${cds:-}
    #forIncoming=${forIncoming:-true}
    #format=${format:-json}
    #withCustomValidations=${withCustomValidations:-true}

    $apiPath = "/api/v1/data/include/validate"

    Write-Verbose -Message "*** Check input parameters $parameters"
    if (-Not ($parameters.ContainsKey('cds'))) {
        Write-Error -Message "********** ERROR: cds (name of Configuration Data Set) parameter is required !"; exit 1
    } else {
        # Replace cds argument by name as it is expected by API
        $parameters.Add("name", $parameters["cds"])
        $parameters.Remove("cds")
    }

    $response = callSweagleAPI -apiPath $apiPath -parameters $parameters -apiMethod "GET"
    Write-Output $response
}


###########################################
#  MAIN
###########################################

switch ($operation)
{
    "info" { getInfo; Break }
    "upload" { upload -parameters $parameters -filePath $filePath; Break }
    "validate" { validate -parameters $parameters; Break }
    "validationStatus" { validationStatus -parameters $parameters; Break }
    "snapshot" { snapshot -parameters $parameters; Break }
    "export" { export -parameters $parameters -filePath $filePath; Break }
}
