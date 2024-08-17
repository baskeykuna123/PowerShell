PARAM($Action,$Application,$Environment)

switch ($Action) 
      { 
	    "Release" { $Action="unreserve"}
        "Restrict" { $Action="reserve"}
      }

if(!$Action){
	$Application="CLEVA"
	$Environment="PLAB"
	$Action="unreserve"
}

$Environment="DCORP","ICORP","ACORP","PCORP"
$Applications="CLEVA","MyBaloiseWebInternal","MyBaloiseWebBroker","MyBaloiseWebPublic","ESB","MyBaloiseClassic","CentralDataStore","NINA","TALK","Backend"
ManageJenkinsResources -Environment $Environment -Action $Action -Application $Application
