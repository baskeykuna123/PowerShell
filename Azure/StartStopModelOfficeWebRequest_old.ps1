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
    $AzVMHostName="AD2LINE-PROD72"
    $Action="Start"
    $Environment="PROD"
    $Type="HELPDESK"
}

$AzWebHookUri = "https://s2events.azure-automation.net/webhooks?token=G2i8DUxZnCGTIYE1xwhHGE%2fL3nuf0Vk%2fyxU7h9sM7zg%3d" 
$AzAccountName="kurt.renders@baloise.be"
$AzSecurePwd= "76492d1116743f0423413b16050a5345MgB8AFoAcwBTAGMAUgBoADMAYgBsADgAYQBtAHoAVgAyADQAVABaAG4AWQBLAEEAPQA9AHwANQAyADkAMAA3ADMAMAA2AGQAMwBhADUAZAA0AGIAMgA5AGEANQAxADkAMwA0AGEANgA1ADAAZgAxAGQAYwAzAGEAOQBiADkAYgAzADYAYQBjAGMAZQBjAGQANgBkAGMANABjADkAMgAxAGUAZABjADUAZABlAGUAZQA0ADcANQA="

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

$proxyCred = New-Object System.Management.Automation.PSCredential ("balgroupit\h002114", $secpasswd)

[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('http://webproxy.balgroupit.com:3228', $true)
[system.net.webrequest]::defaultwebproxy.credentials = $proxyCred
[system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true

[System.Net.ServicePointManager]::SecurityProtocol= [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'

<#
$mycreds = New-Object System.Management.Automation.PSCredential ($AzAccountName, $secpasswd)
Connect-AzureRmAccount -Subscription "PS-SUB-SH-NP-NONPROD1712" -Credential $mycreds

$vm=Get-AzureRmResource -ResourceGroupName "PS-ARG-BE-ND-MODELOFF1902" -TagName "AdcBookmarkDisplay" -TagValue $AzVMHostName | where-object {$_.ResourceType -like "Microsoft.Compute/virtualMachines"}
$status=Get-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
$currstatus=$status.Statuses | where-object {$_.Code -like "PowerState*"}
$currstatus=$currstatus.Code -replace "PowerState/", ""


if (($currstatus -ieq "running") -and ($Action -ieq "Start") ){
    Write-Host "CurrentState = ""$($currstatus)"" and Action = ""$($Action)"". Nothing to do.."
    exit 1
}

if (($currstatus -ieq "deallocated") -and ($Action -ieq "Stop") ){
    Write-Host "CurrentState = ""$($currstatus)"" and Action = ""$($Action)"". Nothing to do.."
    exit 1
}

#>

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




<#
$doLoop = $true
While ($doLoop) {
    #$job = Get-AzureRmAutomationJob -ResourceGroupName "PS-ARG-BE-ND-MODELOFF1902" –AutomationAccountName "PS-AAA-BE-ND-MODELOFF1902-01" -Id $JobId
    $job = Get-AzureRmAutomationJob -ResourceGroupName "PS-ARG-BE-ND-MODELOFF1902" -AutomationAccountName "PS-AAA-BE-ND-MODELOFF1902-01" -Id $JobId
    $status = $job.Status
    $doLoop = (($status -ne "Completed") -and ($status -ne "Failed") -and ($status -ne "Suspended") -and ($status -ne "Stopped"))
    Start-Sleep -s 60
}

#Get-AzureRmAutomationJobOutput -ResourceGroupName "PS-ARG-BE-ND-MODELOFF1902" –AutomationAccountName "PS-AAA-BE-ND-MODELOFF1902-01" -Id $JobId -Stream Output
Get-AzureRmAutomationJobOutput -ResourceGroupName "PS-ARG-BE-ND-MODELOFF1902" -AutomationAccountName "PS-AAA-BE-ND-MODELOFF1902-01" -Id $JobId -Stream Output
# For more detailed job output, pipe the output of Get-AzureRmAutomationJobOutput to Get-AzureRmAutomationJobOutputRecord
# Get-AzureRmAutomationJobOutput -ResourceGroupName "PS-ARG-BE-ND-MODELOFF1902" –AutomationAccountName "PS-AAA-BE-ND-MODELOFF1902-01" -Id $JobId -Stream Any | Get-AzureRmAutomationJobOutputRecord
#Get-AzureRmAutomationJobOutput -ResourceGroupName "PS-ARG-BE-ND-MODELOFF1902" -AutomationAccountName "PS-AAA-BE-ND-MODELOFF1902-01" -Id $JobId -Stream Any | Get-AzureRmAutomationJobOutputRecord
#>