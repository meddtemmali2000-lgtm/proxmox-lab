# Crée la VM Proxmox Backup Server (PBS) dans VMware Workstation.
# 2 vCPU, disque système 32 Go + disque datastore 64 Go (dynamiques), nic0 -> VMnet8 (NAT).

param(
    [string]$VmRoot = "$env:USERPROFILE\Documents\Virtual Machines\proxmox-lab",
    [string]$IsoPath = "$env:USERPROFILE\Documents\images iso\proxmox-backup-server_4.2-1.iso",
    # PBS recommande 4 Go ; 2 Go suffisent pour un petit lab quand l'hôte manque de RAM
    [int]$MemoryMB = 2048,
    [int]$Cpus = 2,
    [string]$SystemDisk = "32GB",
    [string]$DataDisk = "64GB"
)

$ErrorActionPreference = "Stop"
$vdisk = "C:\Program Files (x86)\VMware\VMware Workstation\vmware-vdiskmanager.exe"

if (-not (Test-Path $IsoPath)) { throw "ISO introuvable : $IsoPath" }

$name = "PBS"
$dir = Join-Path $VmRoot $name
$vmx = Join-Path $dir "$name.vmx"
if (Test-Path $vmx) { Write-Host "$name existe déjà : $vmx"; return }
New-Item -ItemType Directory -Force -Path $dir | Out-Null

& $vdisk -c -s $SystemDisk -a lsilogic -t 0 (Join-Path $dir "$name-system.vmdk") | Out-Null
& $vdisk -c -s $DataDisk   -a lsilogic -t 0 (Join-Path $dir "$name-datastore.vmdk") | Out-Null

$vmxContent = @"
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "21"
displayName = "$name"
guestOS = "debian12-64"
firmware = "efi"
uefi.secureBoot.enabled = "FALSE"
numvcpus = "$Cpus"
cpuid.coresPerSocket = "$Cpus"
memsize = "$MemoryMB"
vhv.enable = "FALSE"
tools.syncTime = "FALSE"
mks.enable3d = "FALSE"
floppy0.present = "FALSE"
sound.present = "FALSE"
usb.present = "FALSE"

pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"

scsi0.present = "TRUE"
scsi0.virtualDev = "pvscsi"
scsi0.pciSlotNumber = "224"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "$name-system.vmdk"
scsi0:1.present = "TRUE"
scsi0:1.fileName = "$name-datastore.vmdk"

sata0.present = "TRUE"
sata0:1.present = "TRUE"
sata0:1.deviceType = "cdrom-image"
sata0:1.fileName = "$IsoPath"
sata0:1.startConnected = "TRUE"

ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "vmxnet3"
ethernet0.pciSlotNumber = "160"
ethernet0.addressType = "static"
ethernet0.address = "00:50:56:2A:20:14"
ethernet0.startConnected = "TRUE"
"@
# VMware ne supporte pas le BOM UTF-8 que PowerShell 5 ajoute avec Set-Content
[IO.File]::WriteAllText($vmx, $vmxContent, (New-Object Text.UTF8Encoding $false))

Write-Host "Créé : $vmx"
