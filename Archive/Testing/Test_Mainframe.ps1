CLS

if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
$Application = "MyBaloiseClassic"
$Env = "DCORP"
Switch($Application)
{
"MyBaloiseClassic" {
		$ServerType="WEBFRONTDB"
		$DBName="Peach_Data"
		}
"ESB" {
		$ServerType="ESBDB"
		$DBName="ESB_2_0"
		}
}
$x = GetEnvironmentInfo  -Environment $Env -ServerType $ServerType
$s = $x.Name
$s

