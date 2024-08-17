Function GetBuildDBVersionForTFSFramework($sourceBranch,$BuildDefinitionID,$DBServer,$Database,$UserID,$Password){
    $Query ="SELECT TOP 1 * FROM Release WHERE GETDATE() <= CONVERT(DATETIME, StartDate, 100)"
    $GetBuildDBVersion=Invoke-Sqlcmd -ServerInstance $DBServer -Database $Database -Query $Query -Username $UserID -Password $Password
    $GetBuildDBVersion=$($GetBuildDBVersion.BuildDBVersion)
    $sourceBranch=$($sourceBranch).split("/")[-1]
    Write-Host "Source branch  :" $sourceBranch
    if($sourceBranch -ilike "R*"){
            $ReleaseID=$([String]$sourceBranch.replace("R","")).split(".")[0]
            if($sourceBranch -ilike "*Baloise*"){
                $ReleaseID=[String]$($BuildDefinitionID.split("_")[0]).replace("R","")
            }
            $Query="SELECT BuildDBVersion FROM Release WHERE ReleaseID='$ReleaseID'"
            $GetBuildDBVersion=Invoke-Sqlcmd -ServerInstance $DBServer -Database $Database -Query $Query -Username $UserID -Password $Password
            $GetBuildDBVersion=$($GetBuildDBVersion.BuildDBVersion)
    }
    Write-Host "Release ID      :"$ReleaseID
    Write-Host "Build DB Version:"$GetBuildDBVersion
    return $GetBuildDBVersion
}