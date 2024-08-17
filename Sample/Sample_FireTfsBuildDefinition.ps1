$tfsUrl = "http://TFS-BE:9091/tfs/DefaultCollection/Baloise"
$buildsURI = $tfsUrl + '/_apis/build/builds?api-version=2.0'
$BuildDefsUrl = $tfsUrl + '/_apis/build/definitions?api-version=2.0'
$buildLog =  "$tfsUrl/_apis/build/builds"

$allbuildDefs = (Invoke-RestMethod -Uri ($BuildDefsUrl) -Method GET -UseDefaultCredentials).value | Where-Object {$_.name -eq "SetupkitsBuild"} | select id,name ## get all relevant builds

foreach ($build in $allbuildDefs)
{
   $body = '{ 
   "parameters":  "{\"PackageVersion\":  \"35.7.0.0\"},{\"PackageVersion\":  \"35.7.0.0\"}",
   "definition": { "id": '+ $build.id + '}, reason: "Manual", priority: "Normal"}' # build body

   Write-Output "Queueing $($build.name)" # print build name

   $buildOutput = Invoke-RestMethod -Method Post -Uri $buildsURI -UseDefaultCredentials -ContentType 'application/json' -Body $body -Verbose # trigger new build 

   $allBuilds = (Invoke-RestMethod -Uri $buildsURI -Method get -UseDefaultCredentials).value # get all builds

   $buildID = ($allBuilds | where {$_.definition.name -eq $build.name })[0].id # get first build id 

   $buildInfo =  (Invoke-RestMethod -Uri "$buildLog/$buildID"  -UseDefaultCredentials -Method get)  # get build info by build ID
   while($buildInfo.status -eq "inProgress") # keep checking till build completed
   {
      Write-Output "Sleep for 5 seconds.."
      Start-Sleep -Seconds 5 # Start sleep for 5 seconds
      $buildInfo =  (Invoke-RestMethod -Uri "$buildLog/$buildID"  -UseDefaultCredentials -Method get) ## get status 
   }

   Write-Output "Build Status : $($buildInfo.result)" # print build result
}