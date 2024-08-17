Function CopyDscModules{
	Param ($DscModule,$ModuleVersion)
	
	$SourcePath = Join-Path $DscModulesRoot -ChildPath $DscModule | Join-Path -ChildPath $ModuleVersion
	$DestinationPath = Join-Path $env:psmodulepath.split(";")[1] -ChildPath $DscModule
	
	if (Test-Path $DestinationPath){
		Remove-Item -Path $destinationPath -Force -Recurse
	}
	Copy-Item -Path $SourcePath -Destination $destinationPath -Force -Recurse	
}