Param(
	[string]$AzAccountName,
	[string]$AzSecurePwd,
	[string]$AzWebHookUri,
	[string]$AzVMHostName,
	[string]$Action
)

if (-not $Action){
    $AzVMHostName="HELPDESK-TEST71"
    $Action="Start"
}

$AzWebHookUri = "https://s2events.azure-automation.net/webhooks?token=G2i8DUxZnCGTIYE1xwhHGE%2fL3nuf0Vk%2fyxU7h9sM7zg%3d" 
$AzAccountName="kurt.renders@baloise.be"
#$AzSecurePwd= "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000bad76ffa3f253e4bba54a87b10a27db30000000002000000000003660000c00000001000000025ba711ee9233818d6f7941af82ee2280000000004800000a0000000100000008178545073c7f23ba568749dcc2a54922000000025853b17c29dc69cc5c8462cc028790648c8d4c57907188583980905fb43f4e814000000b4ced208b54e476a39860001cfe43970c013bb5c"

$AzSecurePwd= "76492d1116743f0423413b16050a5345MgB8AHMAcAB6AFoAUAAvAE0AaQBBAEYAdgBOADEAeQBmAEYAawBaAHIAcgAvAGcAPQA9AHwAYwA5ADgAYgBlADIAZQA2ADIAZgAwADkAOABlAGIAZAAwADEANgBjAGUANAA0AGMAMABmAGEAOQAwADgAYgA0ADQAMABmAGIAOABjADMANAA3ADEAMwA3AGQANABjAGIANgAwADIAMgA0AGIAMQAyADYAZgAzAGEAOABiADcAMgA="

$Parameters = @{
    Parameters= @{
        MODesktop = "$AzVMHostName"
    }
    Request =@{
        #action start to start a virtual machine
        Action = "$Action"
        #action startup to start model office portal
        #Action = "StartUp"
    }
}


#to create securestring==>$Encrypte will contain secure pw string
#$Secure = Read-Host -AsSecureString
#$Encrypted = ConvertFrom-SecureString -SecureString $Secure -key (1..16)

$secpasswd = $AzSecurePwd | ConvertTo-SecureString -Key (1..16)

$proxyCred = New-Object System.Management.Automation.PSCredential ("balgroupit\h002114", $secpasswd)

[system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('http://webproxy.balgroupit.com:3228')
[system.net.webrequest]::defaultwebproxy.credentials = $proxyCred
[system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true

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


#Set-Proxy -server "webproxy.balgroupit.com" -port "3228"
#Remove-Proxy

$body = ConvertTo-Json -InputObject $Parameters -depth 10
$back = ConvertFrom-Json -InputObject $body

Write-output $back.Request.Action
write-output $back.Parameters.Type

$header = @{ message="OPLDJSIdfqk993@DFQldhs"}
$response = Invoke-WebRequest -Method Post -Uri $AzWebHookUri -Body $body -Headers $header 
$JobId = (ConvertFrom-Json ($response.Content)).jobids[0]

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
