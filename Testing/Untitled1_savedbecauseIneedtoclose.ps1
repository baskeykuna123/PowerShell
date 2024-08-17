$ErrorActionPreference="silentlycontinue"
cd "D:\BuildTeam\Pankaj\SoapUITests"
#git clone "http://tfs-be:9091/tfs/DefaultCollection/Baloise/_git/$env:RepositoryName"

git init
git config core.sparseCheckout true
echo Tests/* | out-file -encoding ascii .git/info/sparse-checkout
git remote add -f origin "http://tfs-be:9091/tfs/DefaultCollection/Baloise/_git/TaskEngine"
#git pull origin master
git checkout master

  
#$TestSuite='"'+$($env:TestSuite)+'"'
#.\Testing\DIA_SoapUIExecutor.ps1 -repositoryName "$env:RepositoryName" -soapUIProjectFolder "$env:SoapUIProjectFolder" -Environment "$env:Environment" -soapUIProjectName "$env:SoapUIProjectName" -testSuite "$TestSuite"