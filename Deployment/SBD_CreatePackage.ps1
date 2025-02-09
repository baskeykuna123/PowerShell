Param
(
[String]$BuildRootFolder,
[String]$ServiceName,
[string]$ServiceVersion,
[String]$Platform,
[String]$BuildVersion
)
Clear-host

if (!$BuildRootFolder){
    $BuildRootFolder="E:\B.Esb.36.4\DEBUG.36.24.20210927.083911"
    $ServiceName="Baloise.Esb.Service.BO.Generic.Batch.Outbound.Routing.Transfer"
    $ServiceVersion="2.0"
    $Platform="esb"
    $BuildVersion="36.24.20210927.083911"
}

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

if ([string]::IsNullOrEmpty($BuildVersion)){
	throw "BuildVersion not set."
}

if($Platform -ieq "Esb"){
    $LocalPacakgeFolder=Join-Path $global:ESBDeploymentRootFolder -ChildPath $BuildVersion
    $serviceFullName=[string]::Format("{0}.{1}.ServiceMeta.xml",$ServiceName,$ServiceVersion)
    $serviceMetaFile=[string]::Format("{0}\XML\{1}.{2}.ServiceMeta.xml",$LocalPacakgeFolder,$ServiceName,$ServiceVersion)
	$serviceMetaXml=[xml](get-content filesystem::$serviceMetaFile -Force )
}
else{
    Write-Host "SBD not supported for platform $Platform. Build will be stopped!"
    exit 1
}

Write-Host "==========================Packaging============================================="
Write-Host "Build Root Folder          :"$BuildRootFolder
Write-Host "Build Version              :"$BuildVersion
Write-Host "ServiceName                :"$ServiceName
Write-Host "ServiceVersion             :"$ServiceVersion
Write-Host "================================================================================"
#test

#remove all items in xml folder, except for the ServiceMeta file for this service deployment
Remove-Item -Path "$LocalPacakgeFolder\XML" -Exclude $serviceFullName -Recurse -Force

#check if parameter ServiceName equals the service name in the ServiceMeta file
if ($ServiceName -ine $serviceMetaXml.Service.Name){
    Write-Host "parameter service name is not equal to the service name specified in the service meta xml"
    exit 1
}
#check if parameter ServiceVersion equals the service version in the ServiceMeta file
if ($ServiceVersion -ine $serviceMetaXml.Service.Version){
    Write-Host "parameter service version is not equal to the service version specified in the service meta xml"
    exit 1
}

$applicationShortName=GetApplicationDeploymentFolder($serviceMetaXml.Service.BizTalk.BizTalkApplication)
#copy the BizTakl assemblies to package folder
$serviceMetaXml.Service.BizTalk.Assemblies.Assembly |ForEach-Object  {
    $shortName=GetApplicationDeploymentFolder($_.Name)
    #Copy-Item -Path "$BuildRootFolder\BuildOutput\$ServiceVersion\$($_.Name).dll" -Destination "$LocalPacakgeFolder\$applicationShortName\BizTalkResources\$shortName\$ServiceVersion" -Force
}

#copy the gac assemblies to package folder
$serviceMetaXml.Service.GacAssemblies.GacAssembly |ForEach-Object  {
    $shortName=GetApplicationDeploymentFolder($_.Name)
    #Copy-Item -Path "$BuildRootFolder\BuildOutput\$ServiceVersion\$($_.Name).dll" -Destination "$LocalPacakgeFolder\$applicationShortName\Shared\$shortName\$ServiceVersion" -Force
}

#copy the bindingfile to package folder
if ($serviceMetaXml.Service.BizTalk.Bindings.Deploy.HasBindingFile){
    $sourceFolder="$BuildRootFolder\Deployment\OriginalBindings"
    $destinationFolder="$LocalPacakgeFolder\$applicationShortName\Deployment\BindingFiles"
    if(! (Test-Path -Path $destinationFolder)){
        New-Item $destinationFolder -ItemType "directory"
    }
    Copy-Item -Path "$sourceFolder\$($ServiceName).$($ServiceVersion).BindingInfo.xml" -Destination $destinationFolder -Force
}

