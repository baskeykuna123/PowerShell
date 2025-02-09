$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
. "$ScriptDirectory\fnSetGlobalParameters.ps1"

Function CreateDeployStatusXML(){
Param([String]$Folder)

if(-not(Test-Path $Folder)){
New-Item $Folder -ItemType Directory -Force | Out-Null
}

$DeployStatusXML = 
@"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<DeployStatus>
</DeployStatus>
"@

$DeployStatusXML | out-file (Join-Path $Folder -ChildPath "DeployStatus.xml")
}

Function AddElementWithAttributeToXml(){
    param (
        [string]$XmlPath,
        [string]$ParentElement,
        [string]$NewElementName,
        [string]$NewAttribute,
        [string]$NewAttributeValue
    )
    $DeployStatusXML=[xml] (get-content filesystem::$XmlPath -Force )
    $nodes=$DeployStatusXML.SelectSingleNode($ParentElement)
    $newElement=$DeployStatusXML.CreateElement($NewElementName)
    $newElement.SetAttribute($NewAttribute, $NewAttributeValue)
    $nodes.AppendChild($newElement) | Out-Null
    $DeployStatusXML.Save($XmlPath)
}

Function AddAttributeToElement(){
    param (
        [string]$XmlPath,
        [string]$ParentElement,
        [string]$NewAttribute,
        [string]$NewAttributeValue
    )

    $Xml=[xml] (get-content filesystem::$XmlPath -Force )
    $nodes=$Xml.SelectSingleNode($ParentElement)
    $newElement=$Xml.CreateAttribute($NewAttribute)
    $newElement.Value=$NewAttributeValue
    $nodes.Attributes.Append($newElement) | Out-Null
    $Xml.Save($XmlPath)
}

Function SetAttribute(){
    param (
        [string]$XmlPath,
        [string]$ParentElement,
        [string]$Attribute,
        [string]$NewAttributeValue
    )

    $Xml=[xml] (get-content filesystem::$XmlPath -Force )
    $nodes=$Xml.SelectSingleNode($ParentElement)
    $nodes.SetAttribute($Attribute,$NewAttributeValue)
    $Xml.Save($XmlPath)
}

Function SetValueInConfig(){
    param (
        [string]$XmlPath,
        [string]$Key,
        [string]$NewValue
    )

    $Xml=[xml] (get-content filesystem::$XmlPath -Force )
    $xpath=[String]::Format("//add[@key='{0}']",$key)
    $node= $Xml.configuration.appSettings.SelectSingleNode($xpath)
    $node.SetAttribute("value",$NewValue)
    $Xml.Save($XmlPath)
}

Function AddElementDeploymentStarted(){
    param (
        [string]$XmlPath,
        [string]$ParentElement
    )

    AddElementWithAttributeToXml -XmlPath $XmlPath -ParentElement $ParentElement -NewElementName "DeployStatus" -NewAttribute "status" -NewAttributeValue "Deploying"
}

Function SetElementDeploymentSucceeded(){
    param (
        [string]$XmlPath,
        [string]$ParentElement
    )

    SetAttribute -XmlPath $XmlPath -ParentElement "$ParentElement/DeployStatus"  -Attribute "status" -NewAttributeValue "Deployed"
}

Function ArtifactDeployer(){
Param($Environment,$ApplicationName,$buildnumber,$sourceProject,$applicationType,$SubApplicationName)
	$PackageSource=GetPackageSourcePathforTFSBuilds -BuildNumber $BuildNumber -ApplicationName  $ApplicationName
	$ApplicationSource= join-path $PackageSource -ChildPath "$sourceProject\"
	$AppDataFolder=GetAppDataFolder -ApplicationName $SubApplicationName -Environment $Environment
	$paramxmlfilepath=$PackageSource+ $buildnumber.split('_')[1]+"DeploymentParameters_Resolved.xml"
    $deploymentManifest=[string]::Format("{0}\{1}.{2}DeploymentManifest.xml",$PackageSource, $Environment, $ApplicationName)
	
	$ArtifactDeploymentFolder=Get-DeploymentFolder -ApplicationName $SubApplicationName -ApplicationType $applicationType -Environment $Environment
	
	$AppdataSource=join-path $ArtifactDeploymentFolder -ChildPath "app_data"
	
	Write-Host "===================================================================="
	Write-Host "Environment        : $Environment"
	Write-Host "Build Number       : $buildnumber"
	Write-Host "Deployment Folder  : $ArtifactDeploymentFolder"
	Write-Host "Parameter XML      : $paramxmlfilepath"
	Write-Host "Pacakge Source     : $ApplicationSource"
	Write-Host "AppData Folder     : $AppDataFolder"
	Write-Host "DeploymentManifest : $DeploymentManifest"
	Write-Host "===================================================================="
	
    if (Test-Path $ArtifactDeploymentFolder){	
        Remove-Item "$ArtifactDeploymentFolder" -Force -Recurse
    }
	New-Item $ArtifactDeploymentFolder -Force -ItemType Directory |Out-Null

	if(-not (Test-Path $paramxmlfilepath)){
		Write-Host "Parameter XML not found Deployment Failed: $ArtifactDeploymentFolder"
		EXIT 1
	}	
	
		
		Copy-Item -Path "$ApplicationSource*" -Destination $ArtifactDeploymentFolder -Force -Recurse
		ConfigDeployer -ParameteXMLFile $paramxmlfilepath -Environment $Environment -DeploymentFolder $ArtifactDeploymentFolder

    #do actions for deployment manifest
    if (Test-Path $deploymentManifest){
        write-host "deploymentManifest found."
        DeploymentManifestReader -deploymentManifest $deploymentManifest -packageFolder $PackageSource
    }
	else{
		Write-Warning "deploymentManifest not present. No actions done.."
	}
		
	if (Test-Path $AppdataSource){
			if($AppDataFolder){
				Copy-Item -Path $AppdataSource\*.* -Destination $AppDataFolder -Force -Recurse -Verbose
				Remove-Item  $AppdataSource -Force -Recurse
			}
		}
		else{
			Write-Warning "$($ApplicatioName): AppData folder not found. App Data Deployment was skipped"
		}
}

Function DeploymentManifestReader(){
    param(
        [string]$deploymentManifest,
        [string]$packageFolder
    )

    $deploymentManifestXml=[xml](get-content $deploymentManifest)

    $deploymentManifestXml.SelectNodes("//DeploymentManifest/commonDeployment").ChildNodes  | where {$_.NodeType -ne "Comment"} | foreach {
		$currentAction = $_
		switch ($currentAction.Name){
			"deployResourceFolder"{
				$sourceFolder=$currentAction.Attributes.GetNamedItem("tfsSourceFolder").Value
                $destinationFolder=$currentAction.Attributes.GetNamedItem("destinationFolder").Value
				$sync=$currentAction.Attributes.GetNamedItem("sync").Value
                $fullSourceFolder = Join-Path -Path $packageFolder -ChildPath $sourceFolder
				
				Write-Host "===================================================================="
				Write-Host "common Deployment  : deployResourceFolder"
				Write-Host "Source Folder      : $fullSourceFolder"
				Write-Host "Destination Folder : $destinationFolder"
				Write-Host "SyncAction         : $sync"
				Write-Host "===================================================================="

                if ($sync -ieq "mirror"){
                    Remove-Item $destinationFolder -Recurse -Force
                    New-Item $destinationFolder -Force -ItemType Directory | Out-Null
                }
				
                $copiedItems = Copy-Item "$fullSourceFolder\*.*" -Destination $destinationFolder -Recurse -Force -PassThru
			}
			default {
				Write-Verbose "Action $($currentAction.Name) is not (yet) implemented."
			}
        }
	}


}

Function ConfigDeployer(){
PARAM($ParameteXMLFile,$Environment,$DeploymentFolder)
	cls
	#removing .Deployment files
	get-childitem $DeploymentFolder -filter "*.deployment" -Recurse -force | Remove-Item -Force
	get-childitem $DeploymentFolder -filter "*_TEMPLATE_*" -Recurse -force | Remove-Item -Force

	$params=[xml](get-content $ParameteXMLFile)
    $exceptionExtentions= '.dll','.exe','.gif'
	$params.Parameters.EnvironmentParameters.Environment | where {$_.Name -ine $Environment}|foreach{
        $filter="*$($_.name)*"
        if ( ($Environment -ieq "dcorpbis") -and ($_.name -ieq "dcorp") ){
            Get-ChildItem $DeploymentFolder -Filter $filter -Recurse | Where-Object { ! $_.PSIsContainer -and $_.Name -ilike $filter} | foreach { 
                if ($_.FullName -inotlike "*dcorpbis*"){
                    Remove-Item $_.FullName -Force 
                }
            }
        }
        else{
            Get-ChildItem $DeploymentFolder -Filter $filter -Recurse | Where-Object { ! $_.PSIsContainer -and $_.Name -ilike $filter} | foreach { 
                if (! $exceptionExtentions.Contains($_.Extension)){
                    Remove-Item $_.FullName -Force 
                }
            }
        }
	}
	
	#exclusively added logic ESB Database script files where file name is DCORP.DCORP<Filename>
	if($ParameteXMLFile  -ilike "*ESBDeploymentParameters_Resolved.xml"){
		$filter=$Environment+"*.sql"
		Get-ChildItem $DeploymentFolder -Recurse | Where-Object { ! $_.PSIsContainer -and $_.Name -ilike $filter} | foreach { 
			$filepath=Split-Path -Parent $_.FullName
			$newname=$_.Name -ireplace "$($Environment)\.",""
			$Newfilepath=join-path $filepath  -ChildPath $newname
			if(Test-Path $Newfilepath){
				Remove-Item $Newfilepath -Force
			}
			
		}
	}
	
	$filter=$Environment+"*"
	Get-ChildItem $DeploymentFolder -Recurse | Where-Object { ! $_.PSIsContainer -and $_.Name -ilike $filter} | foreach { 
		$filepath=Split-Path -Parent $_.FullName
		$newname=$_.Name -ireplace "$($Environment)\.","" 
		$newname=$newname -ireplace "$($Environment)","" 
		$Newfilepath=join-path $filepath  -ChildPath $newname
		if(Test-Path $Newfilepath){
			Remove-Item $Newfilepath -Force
		}
		Rename-Item $_.FullName -NewName $newname
	}
}


Function Get-DeploymentFolder(){
	Param(
		[string]$ApplicationType,
		[string]$ApplicationName,
		[string]$Environment
	)	
	switch($ApplicationType){	
		"WindowsService" {
			$folder=[string]::Format("{0}\WindowsService\{1}\",$global:deploymentRootFolder,$ApplicationName)
			if($ApplicationName -ilike "*DocumentTransformBackgroundProcessingService"){
				$folder=[string]::Format("D:\Baloise\WindowsService\{0}\{1}",$Environment,$ApplicationName)
			}
		}
		"WebApplication" {
			$folder=[string]::Format("{0}\WebApplication\{1}\",$global:deploymentRootFolder,$ApplicationName)
		}
		"Website" {
			$folder=[string]::Format("{0}\Website\{1}\",$global:deploymentRootFolder,$ApplicationName)
		}
		"Websites" {
			$folder=[string]::Format("{0}\Websites\{1}\",$global:deploymentRootFolder,$ApplicationName)
		}
		"ConsoleApplication" {
			$folder=[string]::Format("{0}\ConsoleApplication\{1}\",$global:deploymentRootFolder,$ApplicationName)
		}
		"BizTalkServiceEai" {
			$folder=[string]::Format("{0}Eai\{1}\",$global:ESBRootFolder,$ApplicationName)
		}
		"BizTalkServiceEsb" {
		$folder=[string]::Format("{0}Esb\{1}\",$global:ESBRootFolder,$ApplicationName)
		}
		"AdlibWebsite" {
			$folder=[string]::Format("D:\Baloise\WebSite\{0}\{1}\",$Environment,$ApplicationName)
		}
		"AdlibWebApplication" {
			$folder=[string]::Format("D:\Baloise\WebApplication\{0}\{1}\",$Environment,$ApplicationName)
		}
		"ImportMandates" {
			$folder=[string]::Format("E:\Import_Mandates_Extracts\{0}\",$Environment)
		}		
	}
return $folder
}

Function InstallWindowsService(){
PARAM(
	[string]$serviceName,
	[string]$ExeName,
	[string]$username,
	$password,
	[string]$ApplicationType,
	[String]$Environment
)
$password = convertto-securestring -String $password -AsPlainText -Force  
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "$username", $password
$ExePath=Join-Path (Get-DeploymentFolder -ApplicationType $ApplicationType -ApplicationName $serviceName -Environment $Environment) -ChildPath $ExeName
$existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"

if ($existingService -ine $null) {
	Stop-WindowsService -serviceName $serviceName
	$existingService.Delete() | out-null
	Start-Sleep -s $Global:ApplicationStartStopPollingSeconds
}

$Displayname="Baloise "+$serviceName
Write-Host "=========================Recreating Service==========================================="
Write-host "Name             :" $serviceName
Write-host "Display Name     :" $Displayname
Write-host "Exe Path         :" $ExePath
Write-host "Logon User       :" $username
Write-Host "=========================Recreating Service==========================================="

New-Service -BinaryPathName $ExePath -Name $serviceName -Credential $cred -DisplayName $Displayname -StartupType Automatic |Out-Null
Stop-WindowsService -serviceName $serviceName
}

Function Delete-WindowsService(){
    PARAM(
	    [string]$serviceName
    )

    $existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"

    if ($existingService -ine $null) {
        Stop-Service $existingService.Name -Force 
	    $existingService.Delete() | out-null
	    Start-Sleep -s $Global:ApplicationStartStopPollingSeconds
    }
    else{
        write-host "Service with name '$($serviceName)' was not found."
    }

}

Function GetAppDataFolder(){
PARAM(
	[string]$ApplicationName,
	[string]$Environment
	)
	$AppDataSharefolder=Join-Path -path $($global:AppShareRoot) -ChildPath $Environment
	switch($ApplicationName){	
		"MyBaloiseBroker" {
			$AppDataSharefolder=Join-Path -path $AppDataSharefolder -ChildPath "\MercatorWeb\MercatorWebBroker\"
		}
		"MyBaloiseInternal" {
			$AppDataSharefolder=Join-Path -path $AppDataSharefolder -ChildPath "\MercatorWeb\MercatorWebInternal\"
		}
		"MyBaloisePublic" {
			$AppDataSharefolder=Join-Path -path $AppDataSharefolder -ChildPath "\MercatorWeb\MercatorWebPublic\"
		}
		default  {
			$AppDataSharefolder=""	
		}
	}

Return $AppDataSharefolder
}



Function Re-InstallWindowsService(){
PARAM(
	[string]$ServiceName,
	[string]$ServiceDisplayName=$ServiceName,
	[string]$deploymentFolderName,
	[string]$ServiceExeName,
	[string]$username,
	[string]$StartUpType="Automatic",
	$password,
	[string]$ApplicationType,
	[string]$InstallWithInstallUtil=$false,
    [string]$InstallUtilExePath=$global:InstallUtilExePath
)
$securepassword = convertto-securestring -String $password -AsPlainText -Force  
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "$username", $securepassword
if($ApplicationType.StartsWith("Mercator.Legacy","CurrentCultureIgnoreCase")){
    $ServiceExePath=Join-Path $deploymentFolderName -ChildPath $ServiceExeName
}
else{
    $ServiceExePath=Join-Path (Get-DeploymentFolder -ApplicationType $ApplicationType -ApplicationName $deploymentFolderName) -ChildPath $ServiceExeName
    $ServiceExePath='"'+$ServiceExePath+'"'
}
#check if the service Exists

$existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"
if($existingService -ine $null -and $InstallWithInstallUtil -ieq $false) {
	Stop-WindowsService -serviceName $ServiceName
	$existingService.Delete() | out-null
	Start-Sleep -s $Global:ApplicationStartStopPollingSeconds
}



Write-Host "=========================Recreating Service==========================================="
Write-host "Name             : "$ServiceName
Write-host "Display Name     : "$ServiceDisplayName
Write-host "Exe Path         : "$ServiceExePath
Write-host "Logon User       : "$username
Write-host "Service StartType: "$StartUpType
Write-Host "=========================Recreating Service==========================================="

if($InstallWithInstallUtil -ieq $true){
	Write-Host "Service Installation via INSTALLUTIL.EXE"
	Write-host "Uninstalling...$ServiceName"
	#cmd /c """$InstallUtilExePath"" /u ""$ServiceExePath"""
	$out=Invoke-Expression "& `"$InstallUtilExePath`" /u `"$ServiceExePath`" " 
	Write-host "Installating.....$ServiceName"
	#cmd /c """$InstallUtilExePath"" ""$ServiceExePath"""
	$out=Invoke-Expression "& `"$InstallUtilExePath`" `"$ServiceExePath`" "  
	$existingServices = Get-WmiObject -Class Win32_Service | ? { $_.Pathname  -ilike "*$ServiceExePath*" } | select Name
    foreach($name in $existingServices){
		Write-Host "Configuring Service(s)..."
	    $servicename=$name.Name
	    #$argums=@("config", '"$servicename"', 'obj="$username"', 'password="$password"', "start=auto")
        $argums=[string]::Format("config ""$servicename"" ""obj=$username"" password=""$password"" start=""$StartUpType""")
		cmd /c "sc.exe $argums"
	}
}
else{
	Write-Host "Service Installation via Powerhsell"
	New-Service -BinaryPathName $ServiceExePath -Name $ServiceName -Credential $cred -DisplayName $ServiceDisplayName -StartupType $StartUpType	-ErrorAction Stop |Out-Null
}
Stop-WindowsService -serviceName $ServiceName
}

function Copy-FolderWithNetUse(){
    param (
        [string]$SourceFolder,
        [string]$DestinationRootFolder,
        [boolean]$Copy2Root=$true,
        [boolean]$CleanDestinationBeforeCopy=$true
    )

    try{
        #extract version from sourcefolder
        $packageVersion = $SourceFolder | Split-Path -Leaf
        $drive="K:"
        if ($Copy2Root){
            $DestinationFolder="$drive\$packageVersion"
        }
        else{
            $DestinationFolder="$drive\"
        }
	    cmd /c "if exist K:\ (net use K: /delete)"
        cmd /c "net use $drive $DestinationRootFolder /persistent:yes" | Out-Null
	    #remove pakcage folder if already exists
        if($CleanDestinationBeforeCopy -and (Test-Path $DestinationFolder)){
            Write-Host "deleting existing package folder: $DestinationFolder"
            del "$DestinationFolder\*.*" -Force -Recurse
            #sometimes, del does not delete all subfoders - try again using remove-item
            Get-ChildItem -Path  $DestinationFolder -Recurse | Select -ExpandProperty FullName | sort length -Descending | Remove-Item -force  -Recurse
        }
    
        Write-Host "Start copying package folder to: $DestinationRootFolder\$packageVersion"
		#Copy-Item -Path "$($SourceFolder)\*" -Destination "$drive" -Force -Recurse -Verbose -ErrorAction Stop 
		xcopy $SourceFolder $DestinationFolder /S /Y /Q /I /R /E
        cmd /c "net use $drive /d /y"  | Out-Null
    }
    catch
    {
        trhrow $_
    }
}


function Copy-FolderWithPSDrive(){
    param (
        [string]$SourceFolder,
        [string]$DestinationRootFolder,
        [boolean]$Copy2Root=$true,
        [boolean]$CleanDestinationBeforeCopy=$true
    )

    try{
        #extract version from sourcefolder
        $packageVersion = $SourceFolder | Split-Path -Leaf
        $drive="K"
        if ($Copy2Root){
            $DestinationFolder="$($drive):\$packageVersion"
        }
        else{
            $DestinationFolder="$($drive):\"
        }
	    cmd /c "if exist K:\ (net use K: /delete)"
        #cmd /c "net use $drive $DestinationRootFolder /persistent:yes" | Out-Null
        New-PSDrive -Name $drive -PSProvider FileSystem -Root $DestinationRootFolder -Persist
	    #remove pakcage folder if already exists
        if($CleanDestinationBeforeCopy -and (Test-Path $DestinationFolder)){
            Write-Host "deleting existing package folder: $DestinationFolder"
            del "$DestinationFolder\*.*" -Force -Recurse
            #sometimes, del does not delete all subfoders - try again using remove-item
            Get-ChildItem -Path  $DestinationFolder -Recurse | Select -ExpandProperty FullName | sort length -Descending | Remove-Item -force  -Recurse
        }
    
        Write-Host "Start copying package folder to: $DestinationRootFolder\$packageVersion"
		#Copy-Item -Path "$($SourceFolder)\*" -Destination "$drive" -Force -Recurse -Verbose -ErrorAction Stop 
		xcopy $SourceFolder $DestinationFolder /S /Y /Q /I /R /E
        cmd /c "net use K: /d /y"  | Out-Null
    }
    catch
    {
        trhrow $_
    }
}

function Register-Assembly(){
    param (
        [string]$assemblyPath,
        [string]$Registertool
    )
    try{

        switch($RegisterTool){

            "regsvr32.exe" {
                $commandLine = "regsvr32.exe /s ""$assemblyPath"""
            }
            default {
                Write-Host "RegisterTool not valid : " $RegisterTool
                Exit 1
            }
        }
        
        cmd /c "$commandLine"

        if($LastExitCode -eq '0')	    {
            Write-Host "Assembly registered: "$assemblyPath|Out-Host
        }
        else{
            throw "Could not register assembly $assemblyPath. `n LastExitCode: $LastExitCode.  `n ErrorMessage: $out."
        } 
    }
    catch {
        throw $_
    }
}

function Create-ComPlus (){
    param (
        [string]$assemblyName, 
        [string]$targetApplication, 
        [string]$applicationRootDirectory=$null,
        [string]$identity, 
        [string]$pswd, 
        [string]$runForever,
        [bool]$reCreate=$false,
        [string]$RegSvcsVersion="4.0"
    )

    try{

        if($reCreate){
            Remove-ComPlus -targetApplication $targetApplication
        }
        
		if ($RegSvcsVersion -ieq "4.0"){
        
            $scriptPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\RegSvcs.exe"	
        }
        else{
            $scriptPath = "C:\Windows\Microsoft.NET\Framework\v2.0.50727\RegSvcs.exe"	
        }

        if ($applicationRootDirectory){
            $commandLine = "/appdir:`'$applicationRootDirectory`' `'$assemblyName`'"
        }
        else{
	        $commandLine = "`'$assemblyName`' /appname:`'$targetApplication`'"
        }

	    $out=Invoke-Expression "& `"$scriptPath`" $commandLine"  
	    if($LastExitCode -eq '0')	    {
	        Write-Host "COM+ created: "$targetApplication|Out-Host
	    }
        else{
            throw "Could not Create COM+ $targetApplication. `n LastExitCode: $LastExitCode.  `n ErrorMessage: $out."
        }
        
        $comAdmin = New-Object -comobject COMAdmin.COMAdminCatalog
        $apps = $comAdmin.GetCollection(“Applications”)
        $apps.Populate();
        $app=$apps | Where-Object {$_.Name -eq $targetApplication}

        if(!$app) {
            throw “Could not create COM+ ""$targetApplication""”
        }
        
	    if ($identity) {$app.Value("Identity")=$identity}
	    if ($pswd) {$app.Value("Password")=$pswd}
	    if ($runForever){$app.Value("RunForever")=$runForever } # value=1 = leave running when idle}
        $apps.SaveChanges() | Out-Null
    }
    catch
    {
        throw $_
    }
}

function Stop-ComPlus (){
    param (
        [string]$targetApplication
    )

    try{
        $comAdmin = New-Object -comobject COMAdmin.COMAdminCatalog
        $apps = $comAdmin.GetCollection(“Applications”)
        $apps.Populate();

        $index = 0
        foreach($app in $apps) {
            if ($app.Name -eq $targetApplication) {
                $comAdmin.ShutdownApplication($targetApplication)
                Write-Host("Com+ stopped: $targetApplication") 
            }

            $index++
        } 
    }
    catch
    {
        throw $_
    }
}

function Recycle-ComPlus (){
    param (
        [string]$targetApplication,
        [bool]$writeResultToEventLog=$false
    )

    #EventLog settings
    $eventlog = "Application"
    $source = "RecycleComObject"
    $SEventID = 0
    $EEventID = 666
    #Process that COM+ runs under
    $process = "dllhost.exe"

    $RecycleReason = 1
    $ErrorMsg=$null
    $WarningMsg=$null

    try{
        $comAdmin = New-Object -com COMAdmin.COMAdminCatalog
        $applist = $comAdmin.GetCollection("Applications") 
        $applist.Populate()
        $AppID = $applist | where {$_.Name -like "*$targetApplication*"} | select -expand key

        if ($AppID){
            #Find Process ID
            $Commandline = Get-WmiObject Win32_Process -Filter "name = '$process'" | select ProcessID,CommandLine
            $ProcessID = $Commandline | where {$_.Commandline -like "*$AppID*"} | Select -expand ProcessID
            
            if ($ProcessID){
                #Get GUID from Process ID
                $GUID = $comAdmin.GetApplicationInstanceIDFromProcessID($ProcessID)

                #GetCurrentMemory 
                $CurrentMemory = get-process -id $ProcessID | select -ExpandProperty "PrivateMemorySize"
                $ConvertedMemory = [math]::truncate($CurrentMemory / 1MB)

                $comAdmin.RecycleApplicationInstances($GUID,$RecycleReason)
                $Message = " Recylce ok for:$targetApplication `n MemoryBeforeRecycle:$ConvertedMemory MB"
                Write-Host $Message
            }
            else{
                $WarningMsg = " Recylce NOK, no running instance of $targetApplication found."
                Write-Host $WarningMsg
            }
        }
        else{
            $WarningMsg = " Recylce NOK, Com+ application $targetApplication not found."
            Write-Host $WarningMsg
        }
    }
    catch {
        $ErrorMsg = [system.exception]"caught a system exception `n $_"
        Write-Host $ErrorMsg
        throw $ErrorMsg
    }
    Finally {
        if ($writeResultToEventLog){
            if (! [System.Diagnostics.EventLog]::SourceExists($source)) {
                New-EventLog -LogName $eventlog -Source $source
            }
            if($ErrorMsg){
                Write-EventLog -LogName $eventlog -Source $source -EventId $EEventID -EntryType error –Message $ErrorMsg
            } elseif ($WarningMsg) {
                Write-EventLog -LogName $eventlog -Source $source -EventId $EEventID -EntryType Warning –Message "$WarningMsg"
            }
            else {
                Write-EventLog -LogName $eventlog -Source $source -EventId $SEventID -EntryType Information –Message $Message
            }
        }
    }
}

function Remove-ComPlus (){
    param (
        [string]$targetApplication
    )

    try{
        $comAdmin = New-Object -comobject COMAdmin.COMAdminCatalog
        $apps = $comAdmin.GetCollection(“Applications”)
        $apps.Populate();

        $index = 0
        foreach($app in $apps) {
            if ($app.Name -eq $targetApplication) {
                $apps.Remove($index)
                $stat = $apps.SaveChanges()
                Write-Host("Com+ App Removed: $stat") 
            }

            $index++
        } 
    }
    catch
    {
        throw $_
    }
}

function Set-ComPlusConstructorString (){
    param (
        [string]$targetApplication, 
        [string]$targetComponent, 
        [string]$constructorString,
        [string]$propertyName="ConstructorString",
        [string]$propertyValue
    )

	try
	{
        $comAdmin = New-Object -ComObject COMAdmin.COMAdminCatalog
        $apps = $comAdmin.GetCollection("Applications")
        $apps.Populate()
        
        $app = $apps | Where-Object {$_.Name -eq $targetApplication}
        $components = $apps.GetCollection("Components", $app.Key)
        $components.Populate()
       
        $component = $components | Where-Object {$_.Name -eq $targetComponent}

        switch($propertyName){
        
            "ConstructorString"{
                $component.Value("ConstructionEnabled") = $true
                $component.Value("ConstructorString") = $constructorString
            }
            "MaxPoolSize"{
                $component.Value("MaxPoolSize") = $propertyValue
            }
        }
        $components.SaveChanges() | Out-Null
        $apps.SaveChanges() | Out-Null
	}
	catch
	{
		throw $_
	}
}

#Function to get the Package Source Path
Function GetPackageSourcePathforTFSBuilds(){
Param([string]$BuildNumber,[string]$ApplicationName)
    $PackageSourcePath=[string]::Format('{0}\{1}_{2}\{3}\',$global:PackageRoot,$BuildNumber.split('_')[0],$BuildNumber.split('_')[1],$BuildNumber.split('_')[2])
	if(-not (test-path Filesystem::$PackageSourcePath)){
	    $PackageSourcePath=[string]::Format('{0}\{1}\{2}_{3}\{4}\',$global:NewPackageRoot,$ApplicationName,$BuildNumber.split('_')[0],$BuildNumber.split('_')[1],$BuildNumber.split('_')[2])
	}
	if(-not (test-path Filesystem::$PackageSourcePath)){
		Write-error "Pacakage source path doest not exist  : - " Filesystem::$PackageSourcePath
		Exit 1
	}
Return $PackageSourcePath
}

#Check if its TFS build or not
Function CheckifTFSBuild(){
Param([string]$BuildNumber,[string]$ApplicationName)
    $PackageSourcePath=[string]::Format('{0}\{1}_{2}\{3}\',$global:PackageRoot,$BuildNumber.split('_')[0],$BuildNumber.split('_')[1],$BuildNumber.split('_')[2])
	if(-not (test-path Filesystem::$PackageSourcePath)){
	    $PackageSourcePath=[string]::Format('{0}\{1}\{2}_{3}\{4}\',$global:NewPackageRoot,$ApplicationName,$BuildNumber.split('_')[0],$BuildNumber.split('_')[1],$BuildNumber.split('_')[2])
	}
	if(-not (test-path Filesystem::$PackageSourcePath)){
		Write-Host "This is not a TFS build!"
		Return $false
	}
Return $true
}

Function NINADownloadXSDAfterDeployment(){
PARAM($Environment,$DeploymentFolder)
	$XSDTypes="basetypes,producttypes,product,documentdata,contract"
	$XSDDeploymentFolder=join-path $DeploymentFolder -ChildPath "Xsd"
	New-Item $XSDDeploymentFolder -ItemType Directory -Force | Out-Null
    
	foreach($XSDType in $XSDTypes.split(',')){
		$XSDURL=[string]::Format("http://localhost/xsd/{0}",$XSDType)
        $XSDDestination=join-path $XSDDeploymentFolder -ChildPath "$($XSDType).xsd"
		Invoke-WebRequest -Uri "$XSDURL" -OutFile $XSDDestination -Verbose
	}
}


