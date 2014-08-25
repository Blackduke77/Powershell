<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2014 v4.1.63
	 Created on:   	25/08/2014 16:12
	 Created by:   	Robbie Roberts
	 Organization: 	
	 Filename:     	Spaces-Create_Cluster_Disk_Witness.ps1
	===========================================================================
	.DESCRIPTION
		The script creates the Scale Out File Server Disks witness disk

	.EXAMPLE
		.\Spaces-Create_Cluster_Disk_Witness.ps1 -PoolName <> -SOFSName <>
#>


param (
	[string]$PoolName,
	[string]$SOFSName)

if (!($PoolName))
{
	Write-Host "Please enter a pool name" -ForegroundColor Red
	Write-Host "Usage: .\Creating_Cluster_Disk_Witness.ps1 -PoolName <> -SOFSName <>" -ForegroundColor Yellow
	exit 0
}

if (!($SOFSName))
{
	Write-Host "Please enter the Scale-Out File Server name" -ForegroundColor Red
	Write-Host "Usage: .\Creating_Cluster_Disk_Witness.ps1 -PoolName <> -SOFSName <>" -ForegroundColor Yellow
	exit 0
}

$WitnessVDName = "Cluster_Quorum_Witness_Disk"
$HDDTierName = "HDDTier_Witness"

Write-Host "Creating Cluster Disk Witness" -ForegroundColor Yellow


function Prepare-QorumVirtualDisk
{
	param ($VD,
		[string]$VDName)
	
	$MyName = hostname
	Get-ClusterGroup "Available Storage" | Move-ClusterGroup -Node $MyName
	
	Write-Host "Prepare the disk for use (Initialize/Create Partition/Initialize the Volume)"
	$vDisk = get-disk | ? { $_.UniqueId -match $VD.UniqueId }
	$vDiskNum = $vDisk.Number
	
	Write-Host "Disk is part of cluster; Put it in maintenance mode before volume creation" -ForegroundColor Yellow
	$VD | Get-ClusterResource | Suspend-ClusterResource
	Start-Sleep -Seconds 10
	
	Write-Host "Clear IsOffline flag" -ForegroundColor Yellow
	Get-Disk -Number $vDiskNum | Set-Disk -IsOffline $false
	Write-Host "Clear Read only flag" -ForegroundColor Yellow
	Get-Disk -Number $vDiskNum | Set-Disk -IsReadOnly $false
	# Clear-Disk -Number $vDiskNum -RemoveData:$true -confirm:$false
	
	# Initialize-Disk -Number $vDiskNum -partitionstyle GPT -confirm:$false
	$newPart = New-Partition -DiskNumber $vDiskNum -UseMaximumSize
	Start-Sleep -Seconds 5
	Initialize-Volume -Partition $newPart -FileSystem NTFS -NewFileSystemLabel $VDName -ShortFileNameSupport $false -AllocationUnitSize 64KB -Confirm:0
	Start-Sleep -Seconds 5
	
	Write-Host "Put the disk out of maintenance mode" -ForegroundColor Yellow
	$DiskRes = Get-ClusterResource | ? { $_.Name -match $VDName }
	Resume-ClusterResource $DiskRes.Name
}

# Create highly availaiable scale out file server role
Add-ClusterScaleOutFileServerRole -Name $SOFSName

# Retrieve the StoragePools created and pick the first one
$Pools = Get-StoragePool | ? { $_.FriendlyName -match $PoolName }
$WPool = $Pools[0].FriendlyName

# Create the HDD Tier
Write-Host "Creating the HDD Tier" -ForegroundColor Yellow
$HDDTier = New-StorageTier -StoragePoolFriendlyName $WPool -FriendlyName $HDDTierName -MediaType HDD
if (!($HDDTier))
{
	Write-Host "Failed to create the HDD Tier" -ForegroundColor Red
	exit 0
}

# Create the Witness Virtual Disk on the First pool selected from above
Write-Host "Create the Witness VD" -ForegroundColor Yellow
$WitnessVD = New-VirtualDisk -StoragePoolFriendlyName $WPool -FriendlyName $WitnessVDName -StorageTiers $HDDTier -StorageTierSizes 1GB -ResiliencySettingName Mirror -NumberOfDataCopies 3 -WriteCacheSize 1GB -NumberOfColumns 1 -Interleave 64KB
if (!($WitnessVD))
{
	Write-Host "Failed to create the witness VD" -ForegroundColor Red
	exit 0
}

# Initialize/Create Volume on the above created virtual disk
Prepare-QorumVirtualDisk $WitnessVD $WitnessVDName

# Retrieve the name of the Cluster Disk that corresponds to the above created Witness Disk
# This is the name we use to add it to the cluster as a disk witness
$WitnessClusterDiskName = (Get-ClusterResource | ? { ($_.ResourceType -match "Physical Disk") } | Get-ClusterParameter VirtualDiskName | ? { $_.Value -match $WitnessVDName }).ClusterObject.Name
if (!($WitnessClusterDiskName))
{
	Write-Host "Unable to query the name of the Cluster Disk" -ForegroundColor Red
	exit 0
}
Write-Host "Change Quorum Model" -ForegroundColor Yellow
Set-ClusterQuorum -DiskWitness $WitnessClusterDiskName