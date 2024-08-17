

Template_RTB_Jenkins_Menu.pf :
	is the active template in the jenkins pipeline (2. TALK IAP Deployments)
	RTB Database port : 16117 (production)

	in powershell script : TALK_RTB_Deployment.ps1
        (\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Deployment)
------------------------------------------------------------------------------------

Template_Version_Title.pf :
        is the active template in the jenkins pipeline (2. TALK IAP Deployments)
        STDDB Database port : 15603 (Icorp, Acorp)

	in powershell script : TALK_ApplicationDeployer.ps1
        (\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Deployment)


====================================================================================
in Scripts (save) Folder :
	p_files and Cmd-files are located on the build-server and also executed on build-server
	(E:\BuildScripts\RTB_Deploy)


	OpenEdge scripts : executed by cmd files
	----------------------------------------
 	Make_Release_Deploy-Front.p  	(RTB)
	Version_Title.p			(Version in application title)


	Cmd files :
	-----------
	Start.bat			(RTB)
	Version_Title.bat		(Version)

====================================================================================

In Save Folder :

16117-PROD_Template_RTB_Jenkins_Menu.pf : 
	template used in normal IAP deployments
	Database port 16117
	is now activ in Jenkins pipeline : Template_RTB_Jenkins_Menu.pf


20666-TESTLME_Template_RTB_Jenkins_Menu.pf :
	template to be used in testing Jenkisn Pipeline
	Database port : 20666
	Database is extra to forseen, as a copy of production RTB

====================================================================================
