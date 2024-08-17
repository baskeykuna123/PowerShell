Param(
	[string]$AzAccountName,
	[string]$AzSecurePwd,
	[string]$AzWebHookUri,
	[string]$AzVMHostName,
	[string]$Action,
    [string]$Environment,
    [string]$Type
)

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

if (-not $Action){
    $AzVMHostName="HELPDESK-PROD70"
    $Action="Start"
    $Environment="PROD"
    $Type="HELPDESK"
}

$AzWebHookUri = "https://s2events.azure-automation.net/webhooks?token=G2i8DUxZnCGTIYE1xwhHGE%2fL3nuf0Vk%2fyxU7h9sM7zg%3d" 

#credentials for kurt renders
#$AzAccountName="kurt.renders@baloise.be"
#$AzSecurePwd= "76492d1116743f0423413b16050a5345MgB8AFoAcwBTAGMAUgBoADMAYgBsADgAYQBtAHoAVgAyADQAVABaAG4AWQBLAEEAPQA9AHwANQAyADkAMAA3ADMAMAA2AGQAMwBhADUAZAA0AGIAMgA5AGEANQAxADkAMwA0AGEANgA1ADAAZgAxAGQAYwAzAGEAOQBiADkAYgAzADYAYQBjAGMAZQBjAGQANgBkAGMANABjADkAMgAxAGUAZABjADUAZABlAGUAZQA0ADcANQA="

#credentials for Tfs Build Service account
$AzAccountName="balgroupit\L002867"
$AzSecurePwd= "76492d1116743f0423413b16050a5345MgB8AC8AZQBUAGcARQBUAEkAeABIAFQASgBEAE4AYwBNAHoANwBJAGcAbwAwAFEAPQA9AHwANABlADUAYQA4ADYAMgA5ADAAMgBkADUAZQBiAGEAZgAzAGYAMwBlADAAZABkADEANAA1ADkAMQBkADYAYgAxADIAMgAzADUAMQBhADUANgAzAGYANgA0ADYAZQAxAGYANgAzADUAOABlADkAOQA1AGYANgBkADIANQBkAGYAZAA="

$Parameters = @{
    Parameters= @{
        MODesktop = "$AzVMHostName"
        Environment="$Environment"
        Type="$Type"
    }
    Request =@{
        Action = "$Action"
    }
}

#to create securestring==>$Encrypte will contain secure pw string
#$Secure = Read-Host -AsSecureString
#$Encrypted = ConvertFrom-SecureString -SecureString $Secure -key (1..16)

$secpasswd = $AzSecurePwd | ConvertTo-SecureString -Key (1..16)

$proxyCred = New-Object System.Management.Automation.PSCredential ($AzAccountName, $secpasswd)

[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('http://webproxy.balgroupit.com:3038', $true) 
[system.net.webrequest]::defaultwebproxy.credentials = $proxyCred
[system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true

[System.Net.ServicePointManager]::SecurityProtocol= [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'

$body = ConvertTo-Json -InputObject $Parameters -depth 10

$header = @{ message="OPLDJSIdfqk993@DFQldhs"}
$response = Invoke-WebRequest -Method Post -Uri $AzWebHookUri -Body $body -Headers $header 
$JobId = (ConvertFrom-Json ($response.Content)).jobids[0]
Write-Host "Azure Job created with Id = " $JobId  `n
Write-Host "Following up job status..."


$body= @{
  "jobid"="$JobId"
} | ConvertTo-Json 

$doLoop = $true
While ($doLoop) {
    $uri=[string]::Format("https://modeloffice.azurewebsites.net/api/Get-Jobstatus?code=wUYrzHrzHAsW8aL8bSqjjIt5tXkgi481QiujJ8q67fqa11GvtGtD5g==&JobID={0}",$jobID)
    $return= Invoke-WebRequest -Method Post -Body $body -Uri $uri
    $status= ConvertFrom-Json -InputObject $return
    $status.Status
    $doLoop = (($status.Status -ne "Completed") -and ($status.Status  -ne "Failed") -and ($status.Status  -ne "Suspended") -and ($status.Status  -ne "Stopped"))
    Start-Sleep -s 30
}

$body= @{
  jobid="$JobId"
  outputtype= "Output"
} | ConvertTo-Json

Write-Host "`nGetting Job output ..."  

$uri=[string]::Format("https://modeloffice.azurewebsites.net/api/Get-Joboutput?code=0cBzrb7Pv4nTxSsfFR2zar2F9RNfWJhY7B79cCJAUbd3lfsad01MWQ==&JobID={0}&outputtype=Output",$jobID)
$return= Invoke-WebRequest -Method Post -Body $body -Uri $uri
$out= ConvertFrom-Json -InputObject $return 
$out | ForEach {
    $_.Summary
}


#add new vm name to file for Jenkins dropdown list
if ($Action -ieq "Deploy"){
    $doReplace=$false
    $file=$Global:JenkinsBIPropertiesFile
    $AzVMHostName=$out[$out.count-1].Summary
    (Get-Content $file ) | foreach {
        if ($_ -imatch "ModelOfficeAvailableVMs" -and $_ -inotmatch $AzVMHostName){
            $doReplace=$true
            $Line=$_
        }
    }

    #Only add new pc to list if it does not exist in the list yet
    if ($doReplace){
        $Utf8BomEncoding = New-Object System.Text.UTF8Encoding($True)
        $currentVMs=($Line -split "=")[1]
        if ($currentVMs.Length -gt 0){
            $newLine = [string]::Format("{0},{1}",$Line,$AzVMHostName)
        }
        else{
            $newLine = [string]::Format("{0}{1}",$Line,$AzVMHostName)
        }
        
		$newVMs = ($newline -split "=")[1] -split "," | Sort-Object
        $newVMs  = $newVMs -join ","
        $newLine = [string]::Format("ModelOfficeAvailableVMs={0}",$newVMs)
		
        $content = (Get-Content $file) -ireplace '(^ModelOfficeAvailableVMs=\S*)', $newLine 
        [System.IO.File]::WriteAllLines($file,$Content,$Utf8BomEncoding)
    }
}

#Remove vm name from file for Jenkins dropdown list
if ($Action -ieq "Delete"){
    $doReplace=$false
    $file=$Global:JenkinsBIPropertiesFile

    (Get-Content $file ) | foreach {
        if ($_ -imatch "ModelOfficeAvailableVMs" -and $_ -imatch $AzVMHostName){
            $doReplace=$true
            $Line=$_
        }
    }

    if ($doReplace){
        $Utf8BomEncoding = New-Object System.Text.UTF8Encoding($True)
        $currentVMs=($Line -split "=")[1]

        $currentVMs = $currentVMs -ireplace ",$AzVMHostName",""
        $currentVMs = $currentVMs -ireplace "$AzVMHostName,",""
        $currentVMs = $currentVMs -ireplace "$AzVMHostName",""

        $newLine = [string]::Format("ModelOfficeAvailableVMs={0}",$currentVMs)

        $content = (Get-Content $file) -ireplace '(^ModelOfficeAvailableVMs=\S*)', $newLine 
        [System.IO.File]::WriteAllLines($file,$Content,$Utf8BomEncoding)
    }
}

