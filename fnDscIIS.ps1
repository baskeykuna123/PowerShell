Function CreateApplicationPool () {

	param(
		[String]$Name,
		[String]$ManagedRuntimeVersion,
		[String]$ManagedPipelineMode,
		[bool]$enable32BitAppOnWin64,
		[String]$restartTimeLimit,
		[String]$restartSchedule,
		[String]$AppPoolUserName,
		[String]$AppPoolPassword
	)

	# if $Name is not set, it means the script has been called without parameters, meaning it is done for testing, so assign test values
	if (!$Name) {
		[String]$Name="testAppPoolBis2"
		[String]$ManagedRuntimeVersion="v4.0"
		[String]$ManagedPipelineMode="Integrated"
		[bool]$enable32BitAppOnWin64=$false
		[string]$restartTimeLimit = '00:00:00'
		[string]$restartSchedule = @('2:30:00')
		[String]$AppPoolUserName="AppPoolUserName"
		[String]$AppPoolPassword="AppPoolPassword"
		$VerbosePreference = "Continue"
		#$VerbosePreference = "SilentlyContinue"
	}

	$AppPoolData = @{
	    AllNodes = @(
	        @{
	            NodeName = "localhost";
				appPoolName = $Name;
				managedRuntimeVersion = $ManagedRuntimeVersion;
				managedPipelineMode = $ManagedPipelineMode
				enable32BitAppOnWin64 = $enable32BitAppOnWin64
				restartTimeLimit = $restartTimeLimit
				restartSchedule = $restartSchedule
				AppPoolUserName = $AppPoolUserName;
				AppPoolPassword = $AppPoolPassword;			
				# More Info: http://goo.gl/3dDHzw
	            PSDscAllowPlainTextPassword  = $true;
	            PSDscAllowDomainUser         = $true
	        }
	    )
	}

	dscApplicationPool  -ConfigurationData  $AppPoolData
	$mofDir = Join-Path -path $currentDir "dscApplicationPool" 
	Start-DscConfiguration $mofDir -ComputerName 'localhost' -Wait -Force

}

Function CreateWebSite () {

	param(
		[String]$WebSiteName, 
		[String]$Port,
		[String]$ApplicationPool
	)

	# if $WebSiteName is not set, it means the script has been called without parameters, meaning it is done for testing, so assign test values
	if (!$WebSiteName) {
		[String]$WebSiteName="TestWebSite"
		[String]$Port="8017"
		$VerbosePreference = "Continue"
		#$VerbosePreference = "SilentlyContinue"
	}

	$WebSiteData = @{
	    AllNodes = @(
	        @{
	            NodeName = "localhost";
				WebSiteName = $WebSiteName;
				Port = $Port
				AppPool = $ApplicationPool
	        }
	    )
	}

	dscWebSite  -ConfigurationData  $WebSiteData
	$mofDir = Join-Path -path $currentDir "dscWebSite" 
	Start-DscConfiguration $mofDir -ComputerName 'localhost' -Wait -Force
}

Function CreateWebApplicationInWebsite () {

	param(
		[String]$ProjectName,
		[String]$WebSiteName,
		[String]$ApplicationPool,
		[bool]$AnonymousAuthentication,
        [bool]$BasicAuthentication,        
        [bool]$WindowsAuthentication,
		[String]$FormsAuthentication,
		[bool]$AspImpersonation
	)

	# if $WebSiteName is not set, it means the script has been called without parameters, meaning it is done for testing, so assign test values
	if (!$WebSiteName) {
		[String]$WebSiteName="TestWebSite"
		[String]$Port="8017"
		[String]$ManagedRuntimeVersion="4.0"
		[String]$AppPoolUserName="AppPoolUserName"
		[String]$AppPoolPassword="AppPoolPassword"
		[String]$ProjectName = "TestProject"
		[String]$VirDirAppPoolUserName = "VirDirAppPoolUserName"
		[String]$VirDirAppPoolPassword = "VirDirAppPoolPassword"
		$VerbosePreference = "Continue"
		#$VerbosePreference = "SilentlyContinue"
	}

	$WebApplicationData = @{
	    AllNodes = @(
	        @{
	            NodeName = "localhost";
				WebSiteName = $WebSiteName;
				VirDirName = $ProjectName;
				AppPool = $ApplicationPool
     			Anonymous = $AnonymousAuthentication
        		Basic = $BasicAuthentication
        		Windows = $WindowsAuthentication
	        }
	    )
	}

	dscWebApplicationInWebSite  -ConfigurationData  $WebApplicationData
	$mofDir = Join-Path -path $currentDir "dscWebApplicationInWebSite" 
	Start-DscConfiguration $mofDir -ComputerName 'localhost' -Wait -Force
			
	#Set Authentication that cannot be set via DSC
	$iisFolder = "IIS:\sites\$WebSiteName\$ProjectName"				
	#Set FormsAuthentication 
	$config = (Get-WebConfiguration system.web/authentication $iisFolder)
	if ($FormsAuthentication -ne "Forms"){
		$config.mode = "Windows"
	}
	else{
		$config.mode = "Forms"
	}
	$config | Set-WebConfiguration system.web/authentication
	#Set AspImpersonation
	$config = (Get-WebConfiguration system.web/identity $iisFolder)
	$config.impersonate = $AspImpersonation
	$config | Set-WebConfiguration system.web/identity
}

Configuration dscApplicationPool
{  
	# Import used Powershell modules
    Import-DscResource -Module xWebAdministration
	
	node $AllNodes.NodeName 
	{	
		# Build Credential based on username and password parameters
    	$AppPoolSecurePassword = ConvertTo-SecureString –String $Node.AppPoolPassword –AsPlainText -Force
    	$AppPoolCredential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $Node.AppPoolUserName, $AppPoolSecurePassword
		
		#Create  ApplicationPool
        xWebAppPool VirDirAppPool
        {
            Name                  = $Node.appPoolName
            IdentityType          = "SpecificUser"
            Credential            = $AppPoolCredential
            State                 = "Started"
            Ensure                = "Present" 
			managedRuntimeVersion = $Node.managedRuntimeVersion
			managedPipelineMode   = $Node.managedPipelineMode
			enable32BitAppOnWin64 = $Node.enable32BitAppOnWin64
			restartTimeLimit      = $Node.restartTimeLimit
			restartSchedule       = $Node.restartSchedule
        }
	}
}

Configuration dscWebSite
{  
	# Import used Powershell modules
    Import-DscResource -Module xWebAdministration
	
	node $AllNodes.NodeName 
	{	

        # Install the Web Server (IIS) Server role
		WindowsFeature IIS
        {			
            Name              = "Web-Server"
            Ensure            = "Present"            
        }
 
        # Install the ASP.NET 4.5 Server role
        WindowsFeature WebAspNet45
        {            
            Name              = "Web-Asp-Net45"
            Ensure            = "Present"
			DependsOn         = "[WindowsFeature]IIS"
        }
		
        # Create Application WebSite folder
		File WebSiteFolder
		{  			
			Type              = "Directory"
			DestinationPath   = Join-Path -Path $deploymentRootFolder $Node.WebSiteName
            Ensure            = "Present"
		}

		# Create WebSite
        xWebsite newWebSite  
        {              
            Name              = $Node.WebSiteName
            State             = "Started" 
            PhysicalPath      = Join-Path -Path $deploymentRootFolder $Node.WebSiteName
            Ensure            = "Present"
			ApplicationPool   = $Node.AppPool
			BindingInfo = @(
	            MSFT_xWebBindingInformation
	            {
	                Protocol              = 'HTTP' 
	                Port                  = $Node.Port
	                IPAddress             = '*'
	            }
			)	
			DependsOn         = @("[File]WebSiteFolder")
        } 
	}
}


Configuration dscWebApplicationInWebSite
{  
	# Import used Powershell modules
    Import-DscResource -Module xWebAdministration
	
	node $AllNodes.NodeName 
	{	

        # Create Virtual Directory folder
		File VirDirFolder
		{  			
			Type              = "Directory"
			DestinationPath   = Join-Path -Path $deploymentRootFolder -ChildPath $Node.WebSiteName | Join-Path -ChildPath $Node.VirDirName
            Ensure            = "Present"
		}

        #Create VirDir in WebSite
        xWebApplication WebApplication
        {
            Name              = $Node.VirDirName
            Website           = $Node.WebSiteName
            WebAppPool        = $Node.AppPool
            PhysicalPath      = Join-Path -Path $deploymentRootFolder -ChildPath $Node.WebSiteName | Join-Path -ChildPath $Node.VirDirName
            Ensure            = "Present"
			
			AuthenticationInfo = MSFT_xWebApplicationAuthenticationInformation
        	{
        		Anonymous = $Node.Anonymous
        		Basic = $Node.Basic
        		Windows = $Node.Windows
        	}
        	
            DependsOn         = @("[File]VirDirFolder")
        }
	}
}