# Luc Mercken
# 2020-02-04
# Enable or disable a windows scheduler
# 2021-08-03 : Luc Mercken : if enable,  first change start time, if scheduler has a repeating triggeraction, then starttime should be in the future
#                            this is only for WorkFlowPoller
#                            added $enviromnemt
#


param($Action,$Name,$Environment)

if($Action -ne "enable" -and $Action -ne "disable") {$Action= "enable"}


write-host "Scheduler : " $Name
write-host "            " $Action
write-host "            " $Environment



if ($Action -eq "disable") {    
    Disable-ScheduledTask -TaskName $Name
}
else {

      if ($Name -eq "WorkFlowPoller") {


           $Logfile="E:\OpenEdge\Wrk\117\pasWorkFlow\openedge\Batch\BatchErrorLog.txt"
           #--------------------------------------------------------------------------------------
           #      Check Log allready exist, if so delete them
           #--------------------------------------------------------------------------------------

          if (test-path $LogFile) {
              write-host ">>  Old Log file is present, will be cleared : " $LogFile  
              remove-item -path $LogFile  -force -recurse -ErrorAction Ignore
          }


          switch($Environment){
	             "DCORP" {				
				          $userid="balgroupit\L001234"
				          $pwd="Dp6unFoU" #| ConvertTo-SecureString -asPlainText -Force
			             }
	             "ICORP" {				
				          $userid="balgroupit\L001235"
				          $pwd="b5VfDZRN" #| ConvertTo-SecureString -asPlainText -Force
			             }
	             "ACORP" {				
				          $userid="balgroupit\L001097"
				          $pwd="Basler09" #| ConvertTo-SecureString -asPlainText -Force
			             }
	             "ECORP" {				
				          $userid="balgroupit\L001097"
				          $pwd="Basler09" #| ConvertTo-SecureString -asPlainText -Force
			             }
	             "PCORP" {				
				          $userid="balgroupit\L001129"
				          $pwd="PMerc_11" #| ConvertTo-SecureString -asPlainText -Force
			             }
          }


          $TimeStamp=((get-date) + (new-timespan -minute 2)).ToString("yyyy/MM/dd HH:mm:ss")
          write-host "TimeStamp : " $TimeStamp

          $TimeNew=$TimeStamp.substring(11,5)
          write-host "TimeNew   : " $TimeNew

          $trigger = New-ScheduledTaskTrigger -Once -At $TimeNew -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days (30 * 365))

          Set-ScheduledTask -TaskName $Name -Trigger $Trigger -User $userid -Password $pwd

      } #WorkFlowPoller

      Enable-ScheduledTask -TaskName $Name
}