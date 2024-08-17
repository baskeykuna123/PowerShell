PARAM($Release,$MatcVersion,$PreviousMatcVersion,$gfiVersion,$TarffVersion,$Branch,$TestEnvironment,$TFSuser,$TFSPassword)


if(!$Release){
	$Release="R32"
    $Branch="V10"
    $MatcVersion="32.10.0"
    $gfiVersion="201020.0.217"
    $TarffVersion="V130"
    $TestEnvironment="ACP"
    $TFSuser="balgroupit\L001146"
    $TFSPassword="Baloise09"
     
}
 
Clear 
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$LatestBuild=Join-Path $global:NewPackageRoot -ChildPath "\Cleva\Builds\ClevaReleaseNotes"
Remove-Item "E:\BuildTeam\ClevaReleaseNotes\*" -Force -Recurse
Write-Host "Downloading the latest Release notes Build ...."
copy-item "$LatestBuild\*" "E:\BuildTeam\ClevaReleaseNotes\" -force -recurse
Set-Location  "E:\BuildTeam\ClevaReleaseNotes\folderStructure\" 
$javajar="java -jar release-notes-0.0.1.jar"
$ExeArgs= @("-Droot.dir=", "-Dbranch=$Branch", "-DpreviousVersion=""$PreviousMatcVersion""","-DcurrentVersion=""$MatcVersion""", "-DgfiVersion=""$gfiVersion""", "-DtariffVersion=""$TarffVersion""", "-Denv=""$TestEnvironment""", "-DtfsUsername=""$TFSuser""",  "-DtfsPassword=""$TFSPassword""")
write-host "Executing The following command `r`n"
write-host "$javajar $ExeArgs"
cmd /c "$javajar $ExeArgs"
#copy output to the location 
Copy-Item "E:\BuildTeam\ClevaReleaseNotes\folderStructure\output\*" -Destination "\\balgroupit.com\appl_data\BBE\transfer\Cleva\ClevaReleasenotes\" -Force -Recurse

     
