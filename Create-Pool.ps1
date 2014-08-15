## CREATE AND CONFIGURE STORAGE POOLS AND SPACES ##
## Author Robbie Roberts
## 15 August 2014


##Create the Storage Pool

# Get the FriendlyName of the Storage Sub System and pass into variable
# Get all Physical Disks that can be pooled and pass into variable

$pool01subsystem = Get-StorageSubSystem | ? FriendlyName -like "*Clustered*"
$PhysicalDisks = (Get-PhysicalDisk -CanPool $True)
$Pool1Name = "AER-Pool1"

New-StoragePool -StorageSubSystemId $pool01subsystem.UniqueId -FriendlyName $Pool1Name -PhysicalDisks $PhysicalDisks


<#
## Remove Storage Pool
Get-StoragePool | ? FriendlyName -Like "*POOL*" | set-storagepool -IsReadOnly 0
Get-StoragePool | ? FriendlyName -Like "*POOL*" | Remove-StoragePool
Get-StoragePool
#>
