Function WebDeployer(){

	Param($environment,$websiteName,$buildnumber,$sourceProject,$applicationType,$deployAppData,$appDataDestination)

	$sourcePath=[string]::Format('{0}\{1}\{2}_{1}\{3}\',$NewPackageRoot,$buildnumber.split('_')[1],$buildnumber.split('_')[0],$buildnumber.split('_')[2])
	$websiteSourcePath=$sourcePath+"$sourceProject\"

	switch($applicationType) {
		"WebSite" 		{$destination=[string]::Format("{0}\WebSite\{1}\",$deploymentRootFolder,$websiteName) }
		"WebApplication" {$destination=[string]::Format("{0}\WebApplication\{1}\",$deploymentRootFolder,$websiteName) }
		default {Write-Warning "Action ""$applicationType"" not defined in fuction WebDeployer."}
	}

	$paramxmlfilepath=$sourcePath+ $buildnumber.split('_')[1]+"DeploymentParameters_Resolved.xml"
	$appdatafilespath=join-path $destination -ChildPath "app_data"
	
	if(Test-Path $destination){
		Remove-Item "$destination*" -Force -Recurse
	}	
	$dummy = New-Item $destination -Force -ItemType Directory 
	Copy-Item -Path "$websiteSourcePath*"-Destination $destination -Force -Recurse
	
	if ($deployAppData -ne $false){
		if(Test-Path $appdatafilespath){
			Copy-Item -Path $appdatafilespath\*.* -Destination $appDataDestination -Force -Recurse -Verbose
			Remove-Item  $appdatafilespath -Force -Recurse
		}
		else{
			Write-Warning "$($websiteName): AppData to deploy = true, but AppData folder not found."
		}
	}
	
	#removing unwanted files
	get-childitem $destination -filter "*config.deployment*" -Recurse | Remove-Item -Force

	$params=[xml](get-content $paramxmlfilepath)
	$params.Parameters.EnvironmentParameters.Environment |foreach{
		if($_.name -ieq $environment){
			$filter=$_.name+"*.config"
			Get-ChildItem $destination -Filter $filter  -Recurse | Where-Object { ! $_.PSIsContainer } | foreach { 
				$filepath=Split-Path -Parent $_.FullName
				$newname=$_.Name.replace("$environment.","")
				$Newfilepath=$filepath+"\"+$newname
				if(Test-Path $Newfilepath){
					Remove-Item $Newfilepath -Force
				}
				Rename-Item $_.FullName -NewName $newname
			}
		}
		else {
			$filter=$_.name+"*.config"
			Get-ChildItem $destination -Filter $filter -Recurse | Where-Object { ! $_.PSIsContainer } | foreach { Remove-Item $_.FullName -Force}
		}
	}
}

Function WebValidator(){
	Param($environment,$websiteName,$buildnumber,$sourceProject,$applicationType)
	
	#WebValidator - todo
}