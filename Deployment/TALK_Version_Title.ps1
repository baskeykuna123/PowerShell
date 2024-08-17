# 2020-08-12 : Luc Mercken : Updating the Application Title with the version number
#                            is integrated in TALK_ApplicationDeployer
#                            this a test script !!!!

clear


$Environment="ACORP"




$Version="32.0.21.1"



$DbServer=[string]::Format("svw-be-tlkc{0}001.balgroupit.com",$Environment[0])

$TemplateFolder="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Templates\Talk\"



#----------------------------------------------------------------------------------------------------------------------
# a menu.pf file is generated from a template, some variables are replaced by actual data
# menu.pf : connect to STDDB db, executing OE_program


$Template_MenuFile=join-path $TemplateFolder -ChildPath "Template_Version_Title.pf"


$Run_MenuFile=join-path "E:\BuildScripts\RTB_Deploy\" -ChildPath "Version_Title.pf"


if (Test-Path $Run_MenuFile) {
    Remove-Item $Run_MenuFile -force -ErrorAction Ignore
}

   

(Get-Content -Path $Template_MenuFile) | Foreach-Object {
    $_ -replace 'xCorp', $Environment `
       -replace 'RelVersion', $Version `
       -replace 'DbServer', $DbServer `       
     } | Set-Content -path $Run_MenuFile


#----------------------------------------------------------------------------------------------------------------------
# Executing Version_Title


$BatFile="E:\BuildScripts\RTB_Deploy\Version_Title.bat"
cmd.exe /C $Batfile


