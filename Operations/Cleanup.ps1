param
(
	[String]$ServerType
)
clear; 

if(!$ServerType){
$ServerType="BALGROUPITSHARE"
}

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$Cleanupinfo=[xml] (Get-Content Filesystem::$global:CleanupXML)
$Rententionlist=$Cleanupinfo.SelectsingleNode("//Cleanup/ServerType[@name='$ServerType']")
$Rententionlist.ChildNodes | Foreach {
	$FolderExlusionlist=$FileExlusionlist=$RetentionDay=$filter=$Retentioncount=$Recursive=""
	$Type=$_.Name
	$folderpath=$_.Path
	$filter=$_.filter
	$RetentionDays=$_.RetentionInDays
	$Retentioncount=$_.RetentionIncount
	if((-not ([string]::IsNullOrEmpty($Retentioncount))) -and (-not ([string]::IsNullOrEmpty($RetentionDays)))){
		Write-Host "Invalid Retention settings, $RetentionDays and $Retentioncount cannot be combine together"
		exit 1
	}
	if($_.FolderExlusionList){
		$FolderExlusionlist=($_.FolderExlusionList).split(',')
	}
	if($_.FileExlusionList){
		$FileExlusionlist=($_.FileExlusionList).split(',')
	}
	if($Type -ieq "File"){
		$Recursive= [boolean]$_.Recurse
	}
	$date=(Get-Date).AddDays(-$RetentionDays)
	if(test-path Filesystem::$folderpath){
		Write-Host "==============================================================================================="
		Write-Host "Type                : " $Type
		Write-Host "Folderpath          : " $folderpath
		Write-Host "Filter              : " $filter
		Write-Host "Retention Days      : " $RetentionDays
		Write-Host "Retention Count     : " $Retentioncount
		Write-Host "Exluded Folders     : " $FolderExlusionlist
		Write-Host "Exluded Files       : " $FileExlusionlist
		Write-Host "Recursive           : " $Recursive
		


	$FolderExlusionlist
	$filestobedeleted=@()
	Switch($Type){
		"File"		{
						if($Recursive){
									
							$Artifactlist=Get-ChildItem -path Filesystem::$folderpath -Force -Recurse -Filter $filter -File 
						}
						else{
							$Artifactlist=Get-ChildItem -path Filesystem::$folderpath -Force -Filter $filter -File
						}
					}
		"Folder"	{
						$Artifactlist=Get-ChildItem -path Filesystem::$folderpath -Force -Filter $filter  -Directory
					
					}
						
	}
	

	#Filter based on Retention
	if(-not ([string]::IsNullOrEmpty($Retentioncount))){
		$FilelistwithRetention = $Artifactlist |  sort LastWriteTime -desc| select -Skip $Retentioncount
	}
	else{
		$FilelistwithRetention = $Artifactlist | Where-Object { $_.LastWriteTime -lt  $date } | sort LastWriteTime -desc
	}

	#check for Exclusions
	$FilelistwithRetention | ForEach-Object {
		$allowedFolder=$true
		$allowedfile=$true
		if($FolderExlusionlist){
			foreach($folder in $FolderExlusionlist){
				$folder="*" + $folder + "*"
				$currentpath=$_.FullName
				if(Test-Path $($_.FullName) -PathType Leaf){
					$currentpath=split-path $_.FullName -Parent 
				}
				if($currentpath -ilike $folder){
			    	$allowedFolder=$false
			    	break;
				}

			}
		}
		if(Test-Path $($_.FullName) -PathType Leaf){
			foreach($file in $FileExlusionlist){
		    	if($_.Name -ilike $file){
					$allowedfile=$false
		        	break;
				}
			}
		}
		if($allowedfile -and $allowedFolder){
			$filestobedeleted+=$_
		}
	}
	if($filestobedeleted){
		Write-Host "The Following files will be deleted"
		$filestobedeleted | ft -Property Name,LastWriteTime -AutoSize
		$filestobedeleted | foreach {
			$Parentfolder=split-path $($_.Fullname) -Parent
			$leaf=$_.Name
			New-PSDrive -Name del -PSProvider FileSystem -Root $Parentfolder | out-null
			$shortfilepath=Join-Path "del:\" -ChildPath $leaf
			Remove-Item $shortfilepath -Recurse -Force
			Remove-PSDrive del -Force 
			}
	}
		Write-Host "==============================================================================================="
}else{
	Write-Host "Path Not Found : $folderpath"
}
}


