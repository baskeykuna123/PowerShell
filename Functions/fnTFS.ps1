$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"
#."$ScriptDirectory\fnUtilities.ps1"

$TFSAssemblies="Microsoft.TeamFoundation.WorkItemTracking.Client.dll",
"Microsoft.TeamFoundation.Client.dll",
"Microsoft.TeamFoundation.VersionControl.Client.dll"

$TFSAssemblyPaths="D:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"D:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio\2017\TeamExplorer\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio\2017\TeamExplorer\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio\2017\TeamExplorer\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"

$TFSInstalled=$false

$TFSAssemblyPaths.GetEnumerator() | foreach {	
	if(test-path $_){
		$Assmeblypath=$_
	}
	
}

if(!$Assmeblypath){
		Write-Host "WARNING:TFS Client Assemblies not found : TFS Fucntions are not loaded"
}
else{
	foreach($assembly in $TFSAssemblies){
		$assemblypath=join-path $Assmeblypath -ChildPath $assembly
		#Write-Host "Loading : $assembly"
		add-type -Path $assemblypath
	}
	Write-Host "SUCCESS:TFS Client Assemblies Loaded Succesfully"			
	
}


function ConnecttoTFS($TFSServer=$global:TFSServer){
	
	$pwd=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
	$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$pwd)
	$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection([String]$TFSServer,$credential)
	$tfs.Authenticate()
	if($tfs.HasAuthenticated -ine $true){
		Write-Host "ERORR: TFS Authentication Failed for user $($global:TFSServer)"
	}
	return $tfs
}


Function Connect2TFSWorkitems($TFSServer=$global:TFSServer)
{	
	$tfs=ConnecttoTFS $TFSServer
	$WIService =$tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
	Return $WIService
}


Function Connect2TFSSourceControl($TFSServer=$global:TFSServer){
	$tfs=ConnecttoTFS $TFSServer
	$sourceControlService = $tfs.GetService([Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer])
	Return $sourceControlService
}



#This Function is used to extract Defect fix info when preparing patches
function WritefixInfo($WorkItemInfo,$TFSPatchInfo,$fixfile)
{
		Remove-Item Filesystem::$fixfile -Force -ErrorAction SilentlyContinue
		Add-Content -Path  filesystem::$fixfile "===============Patch Description======================="
		$fixinfo=[System.Web.HttpUtility]::ParseQueryString($($TFSPatchInfo.Description))
		Add-Content -Path  filesystem::$fixfile -Value $fixinfo
		Add-Content -Path  filesystem::$fixfile "===============Patch Description======================="
		$links=$TFSPatchInfo.get_WorkItemLinks()
		foreach($ln in $links){
			$did=$ln.TargetId
			Add-Content -Path  filesystem::$fixfile "===============Defect :$did======================="
			$defect=$WorkItemInfo.GetWorkItem($ln.TargetId)
			$fixinfo=$defect.Fields["Proposed Fix"].Value
			$fixinfo=$fixinfo -ireplace "<Br>","`r`n"
			$fixinfo=$fixinfo -ireplace "<BR/>","`r`n"
			$fixinfo=$fixinfo -ireplace "</P>","`r`n"
			$fixinfo=$fixinfo -ireplace "<.*?>",""
			$fixinfo=$fixinfo.Trim("`r`n")
			$fixinfo=[System.Web.HttpUtility]::HtmlDecode($fixinfo)
			Add-Content -Path  filesystem::$fixfile -Value $fixinfo 
			Add-Content -Path  filesystem::$fixfile "===============Defect :$did======================="
		}
		
}

	