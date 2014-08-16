## Create CSV's
## Sources that helped
## http://www.aidanfinn.com/?p=15239
##

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
 $Pools = Get-StoragePool | ? {$_.FriendlyName -like "*pool*"}
 $WPool = $Pools[0].FriendlyName
 Get-StoragePool $WPool | New-VirtualDisk -FriendlyName $WPool-SMB02 -IsEnclosureAware $True -ResiliencySettingName Mirror -NumberOfDataCopies 3 -Interleave 65536 –StorageTiers $ssd_tier, $hdd_tier -StorageTierSizes 264GB, 20480GB -WriteCacheSize 5GB -ProvisioningType Fixed
 PrepCSV $WPool-SMB02