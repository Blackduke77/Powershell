## Create CSV's
## Sources that helped
## http://www.aidanfinn.com/?p=15239
## http://superwidgets.wordpress.com/2014/06/22/using-powershell-with-tiered-mirrored-storage-spaces/
#
#
$TieredMirroredvDisks = @("SMB1","SMB2","SMB3","SMB4","SMB5","SMB6")

$Loc = Get-Location
$Date = Get-Date -format yyyyMMdd_hhmmsstt
$logfile = $Loc.path + “\CreateSS_” + $Date + “.txt”
#
function log($string, $color)
{
 if ($Color -eq $null) {$color = “white”}
 write-host $string -foregroundcolor $color 
 $temp = “: ” + $string
 $string = Get-Date -format “yyyy.MM.dd hh:mm:ss tt”
 $string += $temp 
 $string | out-file -Filepath $logfile -append
}
#
Function PrepCSV ($CSVName)
 {
 #Rename the disk resource in FCM
 (Get-ClusterResource | where {$_.name -like “*$CSVName)”}).Name = $CSVName

#Get the disk ID
 Stop-ClusterResource $CSVName
 $DiskID = (Get-VirtualDisk -FriendlyName $CSVName).UniqueId
 Start-ClusterResource $CSVName

#Format the disk
 Suspend-ClusterResource $CSVName
 Get-disk -UniqueId $DiskID | New-Partition -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel “$CSVName” -Confirm:$false
 Resume-ClusterResource $CSVName

#Bring the CSV online
 Add-ClusterSharedVolume -Name $CSVName
 $OldCSVName = ((Get-ClusterSharedVolume $CSVName).SharedVOlumeInfo).FriendlyVolumeName
 Rename-Item $OldCSVName -NewName “$CSVName”
}

#Define the Pool Storage Tiers
 $ssd_tier = New-StorageTier -StoragePoolFriendlyName “AER-Pool1"-FriendlyName SSD_Tier -MediaType SSD
 $hdd_tier = New-StorageTier -StoragePoolFriendlyName “AER-Pool1" -FriendlyName HDD_Tier -MediaType HDD

#Transfer ownership of Available Storage to current node to enable disk formatting
 $MyName = hostname
 Get-ClusterGroup "Available Storage" | Move-ClusterGroup -Node $MyName

 #$Storagepool = Get-StoragePool | ? {$_.FriendlyName -match $PoolName}
 ForEach ($vDisk in $TieredMirroredvDisks) 
 {
 log “Attempting to create vDisk ‘$vDisk’..”
 $Pools = Get-StoragePool | ? {$_.FriendlyName -like "*pool*"}
 $WPool = $Pools[0].FriendlyName
 <#
 Get-StoragePool $WPool | New-VirtualDisk -FriendlyName $WPool-SMB03 -IsEnclosureAware $True -ResiliencySettingName Mirror -NumberOfDataCopies 3 -Interleave 65536 –StorageTiers $ssd_tier, $hdd_tier -StorageTierSizes 264GB, 20480GB -WriteCacheSize 5GB -ProvisioningType Fixed

 PrepCSV $WPool-SMB03
 #>

 $Status = Get-StoragePool $WPool | New-VirtualDisk -FriendlyName $WPool-$vDisk -IsEnclosureAware $True -ResiliencySettingName Mirror -NumberOfDataCopies 3 -NumberOfColumns 4 -Interleave 65536 –StorageTiers $ssd_tier, $hdd_tier -StorageTierSizes 264GB, 5000GB -WriteCacheSize 5GB -ProvisioningType Fixed
 log ($Status | Out-String)
 if ($Status.OperationalStatus -eq “OK”){ 
 log “vDisk ‘$vDisk’ creation succeeded” green}
 else { log “vDisk ‘$vDisk’ creation failed..stopping” yellow; break }
 PrepCSV $WPool-$vDisk
 }
