param($buildVersion,$Environment,$ResultPath)


if(!$buildVersion){
    $buildVersion="1.28.20180830.101426"
    $Environment="DCORP"
    $ResultPath="E:\B.Esb.1.28\Debug.20180830.101428\UnitTests"
    
}

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#Get the application no to be updated

$xml = [xml](Get-Content FileSystem::$global:ReleaseManifest )
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='MercatorESB']")
$ESBbaseVersion=$node.Version.Split('.')[0] + '.' +$node.Version.Split('.')[1]


$buildVersion=$buildVersion.Substring(0,$buildVersion.Length-4)
$buildVersion=$buildVersion.Replace($ESBbaseVersion,"Debug")
$BuildRoot="e:\B.Esb.$($ESBbaseVersion)"
$latestbuildfolder=Get-ChildItem $BuildRoot  -Filter "$($buildVersion)*" |?{$_.PSIsContainer}| sort CreationTime -Descending | select -First 1
Write-Host "Build Number :  " $buildVersion
Write-Host "Build Folder :  " $latestbuildfolder


$latestBuildSource=join-path $($latestbuildfolder.FullName) -ChildPath "Tfs\Source\"
$Testlocation=join-path $($latestbuildfolder.FullName) -ChildPath "UnitTests"
remove-item "$($Testlocation)\*" -Force -Recurse
$buildSequenceFile=join-path $($latestbuildfolder.FullName) -ChildPath "XmlInput\Mercator.Esb.BuildSequence.xml"
$Solutions=[xml](get-content $buildSequenceFile -ReadCount 0 )

Write-host "===================================================================="
Write-host "Environment                :" $Environment
Write-host "TestLocation               :" $Testlocation
Write-host "===================================================================="

$Solutions.BuildSolutions.BuildSolution | foreach{
    $Testlist=$_.UnitTests.TestLists.TestList
    if($Testlist){
    $latestappfolder=$latestBuildSource    
    $appname=$_.Name -replace "Mercator.Esb.Service.",""
    if($_.Name -ilike "Mercator.Esb.Service*"){
        $latestappfolder=join-path $latestappfolder -ChildPath "legacy"
    }
	$appname=$appname -replace "Mercator.Esb.",""
    
	$appname=$appname -replace "Baloise.Esb.",""
	$textfixturesfolder=$_.Name +"\testfixtures\"
	
	
	
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
        $latestappfolder=(get-childitem $latestappfolder -Recurse -Force | ?{$_.PSIsContainer -and $_.FullName -ilike "*\bin\debug"}| sort CreationTime -Descending | select -First 1 ).FullName		
        IF($latestappfolder){
		Write-host "TestAssemblies   :" $latestappfolder
        $Applicationfolder=join-path $Testlocation -ChildPath $textfixturesfolder
        New-Item $Applicationfolder -Force -ItemType Directory | Out-Null
		Remove-item "$($Applicationfolder)\*" -Force -Recurse
		if(test-path filesystem::$vsmdifile){
			copy-item $vsmdifile -Destination $Applicationfolder -Force
            Write-host "Test VSMDI File  :" $vsmdifile
		}
		if(test-path filesystem::$Playlistfolder){
			Copy-Item $Playlistfolder -Destination	(split-path $Applicationfolder -Parent) -Force -Recurse
		}
		
		copy-item "$latestappfolder\*" -Destination $Applicationfolder -Force -Recurse
    }
  }
}




function ExecuteMSTest($testlist,$app,$TempTrxLocation){
	$vsmdifilename=[string]::Format("{0}\{1}\testfixtures\{1}.vsmdi",$Testlocation,$app.Name)
	$resultfile=Join-Path $TempTrxLocation -ChildPath ($testlist+".trx")
    if($vsmdifilename){
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
}


function ExecuteVSTest($list,$app,$TempTrxLocation){
    $Playlistfile=[string]::Format("{0}\{1}\Playlists\{2}.playlist",$Testlocation,$app.Name,$list)
    $Testassembly=[string]::Format("{0}\{1}\testfixtures\{2}.testfixtures.dll",$Testlocation,$app.Name,$app.Name)
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
    set-location $TempTrxLocation
    #"/settings:E:\Build.Mercator.4.23\Build\Output.RunSettings"
    
    & "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe" @("$Testassembly", "/tests:$Testmethods", "/logger:trx")
    
    }
}



$Solutions.BuildSolutions.BuildSolution | foreach{
    $app=$_
	foreach($list in $_.UnitTests.TestLists.TestList){
        Write-Host "Application Name :" $app.Name
		if($app.Name -ieq "Mercator.Esb.Framework"){
			ExecuteMSTest $list $app $ResultPath
			ExecuteVSTest $list $app $ResultPath
		}
	}
	
}

