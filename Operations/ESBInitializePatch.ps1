PARAM($Release)
#Default environment and Application names
if(!$Release){
	$Release = "R26"
}
clear

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$Application = "ESB"
$patchmanifest = $global:PatchManifest
$Patchxml = [xml](Get-Content Filesystem::$patchmanifest)
$patches = $Patchxml.SelectNodes("//Release/Application[@Name='$Application']/PatchRequest")
$DeployXML = "\\SHW-ME-PDNET01\nolio\TFSWorkspace\Mercator.Esb.BuildSequence.xml"
$xml = [xml](Get-Content filesystem::$DeployXML)

$GACUtilPath="E:\Program Files\Mercator\InstallationUtilities\Executables\gacutil.exe"

#Biztalk DB server info
$BiztalkDBservers=@{
	"DCORP" = "sql-bed3-ag02l.balgroupit.com";
	"ICORP" = "sql-bei3-ag02l.balgroupit.com";
	"ACORP" = "sql-bea3-ag02l.balgroupit.com";
	"PCORP" = "sql-bep3-ag02l.balgroupit.com";
}

$patchdrive=$Patchxml.Release.source
foreach ($patch in $patches){
	if ($patch.State -ilike "*Planned")
	{    
		$env = ($patch.State -split " ")[0]
	    $PatchSourcePath =[string]::Format("{0}{1}\{2}\PR-{3}_ESB",$patchdrive,$Release,$env,$patch.number)
		Write-Host "Patch source:" $PatchSourcePath
		cmd /c "net use B: ""$PatchSourcePath""" 
	    $ungacfile = join-path B: -ChildPath "$($patch.number)_UNGAC.bat"
	    $gacfile = join-path B: -ChildPath "$($patch.number)_GAC.bat"
	    if (Test-Path $ungacfile){
	    	Remove-Item -Path "$PatchSourcePath\*.bat" -Force
	    }

    	Write-Host "`nPatch Number : " $patch.number
		Write-Host "==========================$($patch.number)================================================="
    	
		foreach ($Assembly in $patch.Assembly){
			$fileName = [System.io.Path]::GetFileNameWithoutExtension($Assembly.Name)
      		$xmlnodes = $xml.SelectNodes("//BuildSolution/Projects/Project")
      		
			foreach ($node in $xmlnodes) {
        		if (($node.Name) -match $fileName) {
          			$xmlnode = $node.ParentNode.ParentNode
					$rootver = $xmlnode.RootPath.ActiveVersions.Version
					$slnfolder = $xmlnode.Name -replace "Mercator.Esb.",""
					$slnfolder = $slnfolder -replace "Baloise.Esb.",""
					$slnfolder = $slnfolder -replace [regex]::escape('.'),''
					$subfolder = $AssemblyName -replace "Mercator.Esb.",""
					$subfolder = $subfolder -replace "Baloise.Esb",""
        		}
      		}
      		$appname = $xmlnode.Name
	  		Write-Host "-----------------Assemblies-----------------------------------"
      		Write-Host "Assembly Name    : " $Assembly.Name
      		Write-Host "Application Name : " $appname
	  		Write-Host "Assembly Version : " $Assembly.ver
		    $fileinfo = "*" + $Assembly.ver + "*" + $Assembly.Name
      		$assemblypath = Get-ChildItem -Path 'E:\program files\Mercator\ESB\' -Filter *.dll -Recurse | Where-Object { $_.FullName -like $fileinfo } | ForEach-Object { $_.FullName }
      		Write-Host "--" $assemblypath
	  		if(!$assemblypath){
      			Write-Host "Assembly not found.... "
				EXIT 1
      		}
			$appfolder = $appname -replace "Mercator.Esb.",""
			$appfolder = $appfolder -replace "Baloise.Esb.","BE"
			$InstallGAC = [string]::Format('"{1}" /if "{0}" /r FILEPATH "{0}" "ESB"',$assemblypath,$GACUtilPath)
			$UninstallGAC = [string]::Format('"{1}" /u "<AssemblyfileName>" /r FILEPATH "{0}" "ESB"',$assemblypath,$GACUtilPath)
			Add-Content -Path $ungacfile -Value $UninstallGAC -Force
			Add-Content -Path $gacfile -Value $InstallGAC -Force 	  
			$serpath = $assemblypath.Replace("E:\program files\Mercator","")
			$serpath=Split-Path -Parent $serpath
			$finalpath = join-path B: -ChildPath $serpath
			New-Item -ItemType Directory -Force -Path $finalpath | Out-Null
			$filename = join-path B: -ChildPath $($Assembly.Name)
			Move-Item $filename -Destination $finalpath -Force -Verbose
			if ($Assembly.AddtoBiztalkResouces -match "true") {
			
				$AddResourceoutput =[string]::Format("E:\Program Files\Mercator\ESB\{0}\Deployment\{1}_AddResources.txt",$appfolder,$patch.number)
				$BiztalkDBservers.GETENUMERATOR() | foreach {
					$fileName=[string]::Format("B:\{0}_AddResources.bat",$($_.key))
					$command=[string]::Format('"%BTSINSTALLPATH%\btstask.exe" AddResource /ApplicationName:"{0}" /Type:System.BizTalk:BizTalkAssembly /Overwrite /Source:"{1}" /Options:GacOnAdd /Server:{2} /Database:BizTalkMgmtDb >> "{3}"',$appname,$assemblypath,$_.value,$AddResourceoutput)
					Add-Content -Path $fileName -Value $command -Force
				}	
			}
		}
		Write-Host "-----------------Assemblies-----------------------------------"
    	Write-Host "=============================$($patch.number)=============================================="
		$PatchCommandDirectory=[string]::Format("B:\Patch\{0}",$($patch.number))
		New-Item $PatchCommandDirectory -ItemType Directory -Force |Out-Null 
		Move-Item -Path "B:\*.*" -Destination $PatchCommandDirectory
		cmd /c "net use B: /d"
	}
}




