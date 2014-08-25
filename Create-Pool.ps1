<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2014 v4.1.63
	 Created on:   	25/08/2014 16:20
	 Created by:   	Robbie roberts
	 Organization: 	
	 Filename:     	Create-Pool.ps1
	===========================================================================
	.DESCRIPTION
		This script creates a Storage Space Disk Pool using all Physical disks that show they can pool.
		this script is wrtten for use on a scale out file server using clustered storage, it does not
		work with standalone storage.

	.EXAMPLE
		.\Create-Pool.ps1 -PoolName DiskPool1

#>

param ([string]$PoolName)

Write-Host "Creating Storage Pool" -ForegroundColor 'Green'

if (!($PoolName))
{
	Write-Host "Please enter a pool name" -ForegroundColor 'Red'
	Write-Host "Usage: .\Create-Pool.ps1 -PoolName <>" -ForegroundColor 'Yellow'
	Exit 0
}

# Create the Storage Pool

# Get the FriendlyName of the Storage Sub System and pass into variable
# Get all Physical Disks that can be pooled and pass into variable

$pool01subsystem = Get-StorageSubSystem | ? FriendlyName -like "*Clustered*"
$PhysicalDisks = (Get-PhysicalDisk -CanPool $True)

New-StoragePool -StorageSubSystemId $pool01subsystem.UniqueId -FriendlyName $PoolName -PhysicalDisks $PhysicalDisks

<#
## Remove Storage Pool
Get-StoragePool | ? FriendlyName -Like "*POOL*" | set-storagepool -IsReadOnly 0
Get-StoragePool | ? FriendlyName -Like "*POOL*" | Remove-StoragePool
Get-StoragePool
#>
