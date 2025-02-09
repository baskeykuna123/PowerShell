Function CreateRegKey () {

	param(
		[String]$regKey,
	    [String]$regValueName,
	    [String]$regValueData
	)

	# if $Name is not set, it means the script has been called without parameters, meaning it is done for testing, so assign test values
	if (!$regKey) {
		[String]$regKey="HKEY_LOCAL_MACHINE\SOFTWARE\Mercator\Framework\Server\3.10"
	    [String]$regValueName="CommonFolderBis"
	    [String]$regValueData=""
		$VerbosePreference = "Continue"
		#$VerbosePreference = "SilentlyContinue"
	}

	$RegKeyData = @{
	    AllNodes = @(
	        @{
	            NodeName = "localhost";
	        	Key         = $regKey
	        	ValueName   = $regValueName
	        	ValueData   = $regValueData
	        }
	    )
	}

	dscRegistry  -ConfigurationData  $RegKeyData
	$mofDir = Join-Path -path $currentDir "dscRegistry" 
	Start-DscConfiguration $mofDir -ComputerName 'localhost' -Wait -Force

}

Configuration dscRegistry
{  
	# Import used Powershell modules
    #Import-DscResource -Module x
	
	node $AllNodes.NodeName 
	{	
		#Create  RegistryKey
	    Registry RegistryKey
	    {
	        Ensure      = "Present"  # You can also set Ensure to "Absent"
	        Key         = $regKey
	        ValueName   = $regValueName
	        ValueData   = $regValueData
	    }
	}
}
