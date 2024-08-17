$ScriptsFolder=Join-path "E:\BuildTeam\" -childpath "/Scripts/"
New-Item $ScriptsFolder -ItemType Directory -Force | Out-Null
Write-host "`r`n **** Dowloading Scripts to the current Server **** `r`n"
Write-host "`r`n  $ScriptsFolder `r`n"
$ScriptsFolder
$excludes="WSUS","InputParameters"
get-childitem "\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\*" | where-object {$_.Name -notin $excludes}| copy-item -destination $ScriptsFolder -recurse -force



