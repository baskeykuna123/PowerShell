﻿Param($ApplicationName,$VersionType,$Branch,$Release,$BuildStatus)

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

Clear-Host 	
if(!$ApplicationName){
	$ApplicationName="ESB"
	$VersionType="Major"
	$Release="32"
	$Branch="staging"
	$BuildStatus="building"
}



if($Branch -ilike "Dev*"){
    $versionsfilename=[string]::Format("{0}_DebugVersions.properties",$ApplicationName)
	$Buildpropertiesfilename=[string]::Format("{0}_DebugBuild.properties",$ApplicationName)
}
else{
    $versionsfilename=[string]::Format("{0}_StagingVersions.properties",$ApplicationName)
	$Buildpropertiesfilename=[string]::Format("{0}_ReleaseBuild.properties",$ApplicationName)
}


$Newverisoninfo=CreateNewApplicationVersion -ApplicationName $ApplicationName -VersionType $VersionType -Release $Release -Branch $Branch -BuildStatus $BuildStatus
$ApplicationPropertiesfile=join-path $Global:JenkinsPropertiesRootPath -ChildPath $Buildpropertiesfilename
setProperties -FilePath $ApplicationPropertiesfile -Properties $Newverisoninfo

write-host "`r`n Appplication Property File :  - $ApplicationPropertiesfile"
Write-Host "======================================$ApplicationName - New Version =============================================="
displayproperties -properties $Newverisoninfo
Write-Host "======================================$ApplicationName - New Version =============================================="

#populate properties file with all completed versions
if($Branch -ilike "Dev*"){
    $versionsfilename=[string]::Format("{0}_DebugVersions.properties",$ApplicationName)
}
else{
    $versionsfilename=[string]::Format("{0}_ReleaseVersions.properties",$ApplicationName)
}
$versionsPropertiesfile=join-path $Global:JenkinsPropertiesRootPath -ChildPath $versionsfilename
$completedVersionsList=GetCompletedVersionsList -ApplicationName $ApplicationName -Branch $Branch
$list=""
if($completedVersionsList.count){
    for($i=0;$i-ilt $completedVersionsList.count;$i++){
        if ($i -eq 0){
            $list=[string]$completedVersionsList[$i].Version
        }
        else{
            $list+=","+[string]$completedVersionsList[$i].Version
        }
        write-host $completedVersionsList[$i].Version
    }
}
else{
    $list=[string]$completedVersionsList.Version
}

$Properties=@{
	"versions"="$($list)"
}

setProperties -FilePath $versionsPropertiesfile -Properties $Properties
