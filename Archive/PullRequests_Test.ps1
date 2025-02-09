Param($Application,[String]$Sourcepath,$PullRequestfilesPath,$BuildNumber,$Environment)
#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

Clear-Host

if(!$Application){
	$Application="AT-NINA"
    $Sourcepath="E:\TFSBuild\149\s"
	$Environment="DCORP"
	$BuildNumber="Dev_Database_NINA_20210820.2"
	$PullRequestfilesPath="E:\TFSBuild\149\s"
    	#="E:\TFSBuild\174\r"
}

#$Sourcepath
#$ErrorActionPreference='Stop'
$LogPath= Join-path $PullRequestfilesPath -childpath "$Application.txt"
New-Item -ItemType File -Path $LogPath -Force
#Clear-content -path $LogPath

SL $Sourcepath

#git clone $Repo_URL
#SL $Application
$PreviousDate=$(Get-Date).AddDays(-2).ToString("yyyy-MM-dd")
#$PreviousDate="2021-03-03"

$MergeID=$(git log --after="$PreviousDate" --until=$(Get-Date -Format yyyy-mm-dd) --pretty=format:"%p")
$MergeID=$MergeID.Split(" ")[0]
write-host $MergeID

#update the properties specific to the Environemnt for deployment
$propertiesfile=[string]::Format("{0}{1}_{2}Deploy.Properties",$Global:JenkinsPropertiesRootPath,$Environment,$Application)
$propfile=getproperties -FilePath $propertiesfile
$propfile["BuildNumber"]=$BuildNumber
$propfile["MergeID"]=$MergeID
setproperties -FilePath $propertiesfile -Properties $propfile

$HtmlBody=[system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\PullRequest_Status.html" ))
$mailtemphtmlfile = [string]::Format("{0}{1}_URLTest_{2}_{3}.htm",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$Application)

if ($MergeID) { 
$Version = $BuildNumber + "_" + $MergeID
$GetVersionDeploymentStatus = ExecuteSQLonBIVersionDatabase "EXEC GetDeploymentStatusByBuildVersion @BuildVersion='$Version'"
	If($GetVersionDeploymentStatus -ine "Completed"){
#		$MergeID=$MergeID.Split(" ")[0]
		$GetFiles=$(git diff $MergeID --name-only --oneline)
		write-host "List of Files:::"$GetFiles
		$GetFiles | Set-Content -path $LogPath
		$deploymentFolder=join-path $Sourcepath -ChildPath $("\Deployment\" + $((Get-Date).ToString("yyyyMMdd")))
			foreach($line in [system.io.file]::ReadAllLines($LogPath)){
			    $DeployFolderPath=join-path $deploymentFolder -ChildPath $(([String]::Format("{0}\{1}", $line.split('/')[0],$line.split('/')[1])))
			    $sourefilepath=join-path $Sourcepath -ChildPath $line
			    New-Item $DeployFolderPath -Force -ItemType Directory 
			    Write-Host $DeployFolderPath
			    write-host $sourefilepath
			    Copy-Item $sourefilepath -Destination $DeployFolderPath -Force -Recurse
			}
		#ExecuteSQLonBIVersionDatabase "EXEC CreateDeploymentStatus @Application='$ApplicationName',@Environment='$Environment',@BuildVersion='$MergeID',@DeploymentStatus='$DeploymentStatus',@releaseID='$ReleaseID'"

	}
	else{
		Write-Host "Deployment has been completed already for the merge ID - $MergeID. No packaging needs to be done"
	}
}
else{
    $HtmlBody | Out-File Filesystem::$mailtemphtmlfile
	$Mailsubject = "No New Pull Request to Deploy"
	#SendMail -To $MailRecipients -subject $Mailsubject -body $HtmlBody
	SendMailWithoutAdmin -To "snehit.rahate@baloise.be" -subject $Mailsubject -body $HtmlBody
}

#$RepoPath="$WorkspaceRoot\$Application"
#cd $RepoPath
#Remove-Item $RepoPath -Recurse -Force 
 