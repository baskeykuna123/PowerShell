PARAM
	(
	[string]$FilePath,
	[string]$TfsPath,
    [string]$TfsFileName,
	[string]$SourceSystem,
	[string]$Environment
	)
	
if(!$SourceSystem){
	$FilePath=""
	$TfsPath="$/Baloise/CCM/Staging/Deployment/Esb Configuration OMS PhaseOut/TemplateConfiguration.csv"
    $tfsFileName="TemplateConfiguration.csv"
    $SourceSystem="Tfs"
	$Environment="ICORP"    
}

#check if valid parameters are provided
if ( ($SourceSystem -eq "Ntfs") -and ([string]::IsNullOrEmpty($FilePath)) ) {
    write-host "`r`nSourceSystem = Ntfs and filePath = empty.  Provide valid parameters please."
    write-host "`r`n"
    exit
}

if ( ($SourceSystem -eq "Tfs") -and ( [string]::IsNullOrEmpty($TfsFileName) -or [string]::IsNullOrEmpty($TfsPath))  ) {
    write-host "`r`nSourceSystem = Tfs and (TfsPath = empty or TfsFileName = empty).  Provide valid parameters please."
    write-host "`r`n"
    exit
}

#in case of pcorp, only Tfs is allowed + there should not be "dev/general" or "staging" in the tfs path
if ( ($Environment -eq "PCORP") -and ($SourceSystem -eq "Ntfs") ){
    write-host "`r`nOnly Tfs is allowed for Pcorp."
    write-host "`r`n"
    exit
}
if ( ($Environment -eq "PCORP") -and ($TfsPath -like "*dev/general*") ){
    write-host "`r`nPatching from ""dev/general"" branch is not allowed for Pcorp."
    write-host "`r`n"
    exit
}
if ( ($Environment -eq "PCORP") -and ($TfsPath -like "*staging*") ){
    write-host "`r`nPatching from ""staging"" branch is not allowed for Pcorp."
    write-host "`r`n"
    exit
}
if ( ($Environment -eq "PCORP") -and ($TfsPath -notlike "*Production/R*") ){
    write-host "`r`nPatching is only allowed from ""Production/Rxx.x"" branch."
    write-host "`r`n"
    exit
}

#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if ($SourceSystem -eq "Tfs"){
    #$LocalFolder = $ScriptDirectory
	$LocalFolder = Join-Path  $ScriptDirectory -ChildPath "DropFolder"
    Write-host "`r`nLocalFolder: " $LocalFolder
	if(Test-Path -Path "$($LocalFolder)\$($TfsFileName)"){
        Remove-Item "$($LocalFolder)\$($TfsFileName)" -Force
    }
    $Connect2TFSSourceControl = Connect2TFSSourceControl $TFSServer

    $Workspaces = $Connect2TFSSourceControl.QueryWorkspaces("ccmtemp", $env:UserName, $env:COMPUTERNAME)
    if ( !($Workspaces.count -eq 0)){
        foreach ($workspace in $Workspaces){
            $workspace.Delete() | Out-Null
            Write-host "`r`nOld workspace deleted"
        }
    }
    $ws = $Connect2TFSSourceControl.CreateWorkspace("ccmtemp")
    $ws.Map($TfsPath, $LocalFolder) | Out-Null
    $ws.Get() | Out-Null
    $ws.Delete() | Out-Null
	RemoveReadOnly -FolderPath $LocalFolder -Filter "*.csv*"
    $SourceFile = $LocalFolder + "\" + $TfsFileName
}
else{
    Rename-item ".\FilePath" -newname $FilePath 
    $SourceFile = $FilePath    
}

$Destination="\\balgroupit.com\appl_data\BBE\App01\$Environment\CCM\template\Configuration"
#$Destination="\\balgroupit.com\appl_data\BBE\Transfer\Packages\TempTest"
Write-host "`r`nSourceFile  : " $SourceFile
Write-host "`r`nDestination : " $Destination
Write-host "`r`n" 

copy-item $SourceFile -destination $Destination -verbose -force
