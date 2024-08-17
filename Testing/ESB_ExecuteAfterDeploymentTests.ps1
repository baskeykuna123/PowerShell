param($ResultPath,$Environment,$TestArtifactsSharePath,$BuildNumber)

if(!$Environment){
	$Environment="DCORP"
	$TestArtifactsSharePath="\\sql-bed3-work.balgroupit.com\DCORP\Test\"
	$BuildNumber="1.29.20181127.190045"
}
clear


if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#Get the application no to be updated

$xml = [xml](Get-Content FileSystem::$global:ReleaseManifest )

$TestArtifactsSourcepath="\\sql-bed3-work.balgroupit.com\$($Environment)\Test\"
#$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='MercatorESB']")
#$ESBbaseVersion=$node.Version.Split('.')[0] + '.' +$node.Version.Split('.')[1]
$ESBbaseVersion=$BuildNumber.split(".")[0]+'.'+$BuildNumber.split(".")[1]
$TestArtifactPacakgeSource=join-path $global:NewPackageRoot -childpath "DEV_EsbUnitTests\"
$TestArtifactPacakgeSource=(Get-ChildItem filesystem::$TestArtifactPacakgeSource |?{$_.PSIsContainer }| sort CreationTime -Descending | select -First 1).FullName
$EvnironmentArtifacts=join-path $TestArtifactPacakgeSource -ChildPath $Environment
$testsequencefilepath=join-path $TestArtifactPacakgeSource -ChildPath "xml\Baloise.Esb.DeploymentTest.Sequence.xml"
$latestbuildfolder=[string]::Format("\\svw-be-bldp001\e$\B.Esb.{0}\Debug.{1}",$ESBbaseVersion,$BuildNumber)
cmd /c "net use P: $latestbuildfolder /user:prod\builduser Wetzel01"
$Tests=[xml](get-content $testsequencefilepath -ReadCount 0 )
$latestbuildfolder=join-path  "P:\" -ChildPath "Tfs\Source\"
$Testlocation="E:\Program Files\Mercator\Testing\"

Write-host "===================================================================="
Write-host "Environment                :" $Environment
Write-host "TestLocation               :" $Testlocation
Write-Host "Test ArtifactBuild Folder  :" $TestArtifactsSourcepath
Write-Host "latestBuild Folder         :" $latestbuildfolder
Write-host "===================================================================="

#deploying Latest Test Sequence
Copy-Item $testsequencefilepath -Destination $Testlocation -Force
#deploy test artifacts
Write-Host "Copying latest Testartifacts to  $($TestArtifactsSourcepath)"
copy-item "$($EvnironmentArtifacts)\*" -Destination "$TestArtifactsSourcepath" -Force -Recurse
$Tests.AfterDeploymentTests.Application | foreach{
	$latestappfolder=$latestbuildfolder
	$textfixturesfolder=$_.Name +"\testfixtures\"
	$Applicationfolder=join-path $Testlocation -ChildPath $textfixturesfolder
	New-Item $Applicationfolder -Force -ItemType Directory | Out-Null
	$appname=$_.Name -replace "Mercator.Esb.Service.","legacy."
	$appname=$appname -replace "Mercator.Esb.",""
	$appname=$appname -replace "Baloise.Esb.",""
	foreach($folder in $appname.Split('.')){
		$latestappfolder=Join-Path -Path $latestappfolder -ChildPath $folder
	}
	if($appname -eq "Framework"){
		$latestappfolder=Join-Path $latestappfolder -ChildPath "\1.0"
	}
		
		$filename=$_.Name + ".vsmdi"
		$vsmdifile=Join-Path -Path  $latestappfolder -ChildPath $filename
		
		$latestappfolder=join-path $latestappfolder -ChildPath "TestFixtures"
		$Playlistfolder=join-path $latestappfolder -ChildPath "Playlists"
		if(Test-Path $latestappfolder){
		$latestappfolder=(get-childitem $latestappfolder -Recurse -Force | ?{$_.PSIsContainer -and $_.FullName -ilike "*\bin\debug"}| sort CreationTime -Descending | select -First 1 ).FullName
		Write-host "===================================================================="
		Write-host "Test VSMDI File  :" $vsmdifile
		Write-host "TestAssemblies   :" $latestappfolder
		Write-host "===================================================================="
		Remove-item "$($Applicationfolder)\*" -Force -Recurse
		if(test-path filesystem::$vsmdifile){
			copy-item $vsmdifile -Destination $Applicationfolder -Force
		}
		if(test-path filesystem::$Playlistfolder){
			Copy-Item $Playlistfolder -Destination	(split-path $Applicationfolder -Parent) -Force -Recurse
		}
		
		copy-item "$latestappfolder\*" -Destination $Applicationfolder -Force -Recurse
	}
	else{
		Write-Host "$($latestappfolder)... was not found"
	}
}




function ExecuteMSTest($testlist,$app,$TempTrxLocation){
	Write-Host "Application Name :" $app.Name
	$vsmdifilename=[string]::Format("{0}{1}\testfixtures\{1}.vsmdi",$Testlocation,$app.Name)
	$resultfile=Join-Path $TempTrxLocation -ChildPath $testlist".trx"
	if(-not([string]::IsNullOrEmpty($testlist))){
		Write-host "Executing the Tests..."
		Write-host "===================================================================="
		Write-Host "Result File       :" $resultfile 
		Write-Host "VSMDI File        :" $vsmdifilename
		Write-Host "Running Test list :" $testlist
		Write-host "===================================================================="
		& "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Mstest.exe" @("/testmetadata:$vsmdifilename", "/testlist:$testlist",  
		"/resultsfile:$resultfile")
	}
}


function ExecuteVSTest($list,$app){
		$Playlistfile=[string]::Format("{0}{1}\Playlists\{2}.playlist",$Testlocation,$app.Name,$list)
		$Testassembly=[string]::Format("{0}{1}\testfixtures\{2}.testfixtures.dll",$Testlocation,$app.Name,$app.Name)
			if((test-path $Playlistfile) -and (test-path $Testassembly)){
			
			$content=[xml](Get-Content $Playlistfile)
			$content.Playlist.Add | foreach{
				$Testmethods+=$_.Test + ","
			}
			$Testmethods=$Testmethods.Trim(',')
			Write-Host "Application Name :" $app.Name
			Write-host "Executing the Tests..."
			Write-host "===================================================================="
			Write-Host "Running Playlist : " $Playlistfile
			Write-Host "Test Assembly    : " $Testassembly
			#write-host $Testmethods
			Write-host "===================================================================="
			
			& "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe" @("$Testassembly", "/tests:$Testmethods", "/logger:trx", "/settings:E:\Program Files\Mercator\Testing\Output.RunSettings")
		}
}


$Tests=[xml](get-content $testsequencefilepath -ReadCount 0 )
$TempTrxLocation=$ResultPath

foreach($app in $Tests.AfterDeploymentTests.Application){
	New-Item $TempTrxLocation -ItemType Directory -Force | Out-Null 
	foreach($list in $app.UnitEx.TestLists.Testlist){
		ExecuteMSTest $list $app $TempTrxLocation
		ExecuteVSTest $list $app
	}
	
	foreach($list in $app.MappingTest.TestLists.Testlist){
		ExecuteMSTest $list $app $TempTrxLocation
		ExecuteVSTest $list $app
	}
	
	foreach($list in $app.End2EndTest.TestLists.Testlist){
		ExecuteMSTest $list $app $TempTrxLocation
		ExecuteVSTest $list $app	
	}
}



cmd /c "net use P: /d"
