Clear-Host

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$ApplicationType="ESB"
$BuildSequnce="\\SHW-ME-PDNET01\nolio\TFSWorkspace\Mercator.Esb.BuildSequence.xml"

# Read and get values from Global Patch manifest XML file 
$PatchManifestXML=[XML](gc FileSystem::$global:PatchManifest)
$PatchXMLApplication=$($PatchManifestXML.Release.Application|?{$_.name -ieq $ApplicationType})
$ReleaseNo = $PatchManifestXML.Release.Release
$PatchRequestNo = $PatchXMLApplication.PatchRequest.Number

#$AssemblyINFO = $PatchXMLApplication.PatchRequest.Assembly
#$Add2GAC = $AssemblyINFO.AddtoGAC
#$Add2Rsources = $AssemblyINFO.AddtoBiztalkResouces
#$AssemblyName=$AssemblyINFO.Name

$PatchRequestState = $PatchXMLApplication.PatchRequest.State
$PatchRequestState=$PatchXMLApplication.PatchRequest.State
ForEach($state in $PatchRequestState){

    $PatchRequestNumbers=$PatchXMLApplication.PatchRequest|?{$_.State -eq $state}|select Number
	ForEach($PatchRequestNumber in $PatchRequestNumbers)
	{
		$AssemblyWithoutExtension=[System.IO.Path]::GetFileNameWithoutExtension($AssemblyName)

		if($state -ieq "*Planned")
		{
		# Read and get values from BuildSequence XML File
		$BuildSequenceXML=[XML](gc $BuildSequnce)
		$BuildSequenceProjects=$BuildSequenceXML.SelectNodes("//BuildSolution/Projects/Project")
		$SearchProjectwithAssemblyName=$BuildSequenceProjects | ?{$_.name -ilike "$AssemblyWithoutExtension*"}
		$applicationName=$($SearchProjectwithAssemblyName.ParentNode.ParentNode).name
		$ApplicationDeploySequenceName=$applicationName+".DeploySequence.xml"
		$EsbXMLRootFolder=Join-Path $global:ESBRootFolder -ChildPath "\Esb\XML"
		$DeploySequenceXMLFilePath=[String]::Format("{0}\{1}",$EsbXMLRootFolder,$ApplicationDeploySequenceName)

		# Copy ESB Folder from PatchRequest Folder to server Esb location 
		$Environment = $($state -split " ")[0]
		$PatchSourceFolder=$PatchManifestXML.Release.source

		$PatchSourceFolder=[String]::Format("{0}{1}\{2}\PR-{3}_{4}",$PatchSourceFolder,$ReleaseNo,$Environment,$PatchRequestNumber,$ApplicationType)
		$ESBPatchFolder=Join-Path $PatchSourceFolder -ChildPath "ESB"
		Copy-Item $ESBPatchFolder -Recurse -Destination $global:ESBRootFolder -Force -Verbose -Whatif


			if((Test-Path $DeploySequenceXMLFilePath) -eq $true){

			    $DeploySequenceReader=[xml](gc $DeploySequenceXMLFilePath)
			    $ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
			    if($ApplicationConfiguration.GacAssemblies.ChildNodes){
					$GACAssemblies=$ApplicationConfiguration.SelectNodes("//GacAssemblies/Assembly/AssemblyName")
			    }

				$GACAssemblies +=$ApplicationConfiguration.SelectNodes("//PipelineComponents/PipelineComponent")
			    $BiTalkResources=$ApplicationConfiguration.SelectNodes("//BizTalkApplication/BizTalkResources/BizTalkResource")

			    #add assemblies pipeline assemblies to GAC
			    if($GACAssemblies.ChildNodes){
			        ForEach($Assembly in $($GacAssemblies.InnerText))
			        {
			            if($Assembly -ieq $AssemblyName){

			                # Add-Gac Logic
							$SearchDLL=gci $ESBPatchFolder -Recurse -Filter $Assembly
							$DeriveAssemblyPath=$global:ESBRootFolder + $($($SearchDLL.FullName).Replace("$PatchSourceFolder\",""))
							
							if(Test-Path $DeriveAssemblyPath)
							{
			                	Add-GAC  -AssemblyPath $DeriveAssemblyPath
							}	

			            }
			        }
			    }
				
			    if($BiTalkResources.ChildNodes){
			        ForEach($Resource in $($BiTalkResources.BizTalkResourceName))
					{
			            if($Resource -ieq $AssemblyName){
						
			                # Add-Resource Logic
							$SearchDLL=gci $ESBPatchFolder -Recurse -Filter $Assembly
							$DeriveAssemblyPath=$global:ESBRootFolder + $($($SearchDLL.FullName).Replace("$PatchSourceFolder\",""))
							if(Test-Path $DeriveAssemblyPath)
							{
			                	Add-Resources -ApplicationName $applicationName -ResourcePath $DeriveAssemblyPath
							}	
			            }
			        }
			    }  
			}
		}
	}
}	