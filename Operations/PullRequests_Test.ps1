#Param($Application)
CLS
$Application="AT-NINA"
if(!$Application){
	$Application="MDM"
}

$ErrorActionPreference='Stop'
$LogPath="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Operations\$Application.txt"
Clear-content -path $LogPath
$WorkspaceRoot="E:\BuildTeam\GIT"
If(-not (Test-Path $WorkspaceRoot)){
	New-item $WorkspaceRoot -ItemType Directory -Force | Out-Null
}
SL $WorkspaceRoot

$Repo_URL=[String]::Format("http://tfs-be:9091/tfs/DefaultCollection/Baloise/_git/{0}",$Application)
If($Application -ieq 'AT-NINA'){
	$Application='AT%20-%20NINA'
	$Repo_URL=[String]::Format("http://tfs-be:9091/tfs/DefaultCollection/_git/{0}",$Application)
}
$Application
write-host $Repo_URL
$RepoFolder=$Repo_URL.split("/")[-1]
$RepoFolder=Join-Path $WorkspaceRoot $RepoFolder
write-host "$RepoFolder"

if(Test-Path Filesystem::$RepoFolder){
	Remove-Item $RepoFolder -Force -Recurse | ?{$_.PSIsContainer} | Out-Null
}
$Repo_URL
git clone $Repo_URL
SL $Application
$PreviousDate=$(Get-Date).AddDays(-10).ToString("yyyy-MM-dd")
$MergeID=$(git log --after="$PreviousDate" --until=$(Get-Date -Format yyyy-mm-dd) --pretty=format:"%p")
$MergeID=$MergeID.Split(" ")[0]
write-host $MergeID
$GetFiles=$(git diff $MergeID --name-only --oneline)
write-host "List of Files:::"$GetFiles
$GetFiles | Set-Content -path $LogPath
$RepoPath="$WorkspaceRoot\$Application"
#cd $RepoPath
#Remove-Item $RepoPath -Recurse -Force 
 