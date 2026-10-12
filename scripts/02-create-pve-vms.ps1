# Crée les 3 VM Proxmox (PVE1, PVE2, PVE3) dans VMware Workstation.
# Par nœud : 8 Go RAM, 4 vCPU, VT-x imbriqué, disque système 40 Go + disque data 30 Go (dynamiques),
#            ens160 -> VMnet8 (NAT), ens192 -> VMnet10 (cluster).

param(
    [string]$VmRoot = "$env:USERPROFILE\Documents\Virtual Machines\proxmox-lab",
    [string]$IsoPath = "$env:USERPROFILE\Documents\images iso\proxmox-ve_9.1-1.iso",
    [int]$MemoryMB = 8192,
    [int]$Cpus = 4,
    [string]$SystemDisk = "40GB",
    [string]$DataDisk = "30GB",
    # $true seulement si Windows démarre sans Hyper-V (WSL2 indisponible) : sinon la VM refuse de démarrer
    [bool]$NestedVirt = $false
)

$ErrorActionPreference = "Stop"
$vmwDir = "C:\Program Files (x86)\VMware\VMware Workstation"
$vdisk = Join-Path $vmwDir "vmware-vdiskmanager.exe"

if (-not (Test-Path $IsoPath)) { throw "ISO introuvable : $IsoPath" }

$nodes = 1..3
foreach ($n in $nodes) {
    $name = "PVE$n"
    $dir = Join-Path $VmRoot $name
    $vmx = Join-Path $dir "$name.vmx"
    if (Test-Path $vmx) { Write-Host "$name existe déjà, ignoré"; continue }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    & $vdisk -c -s $SystemDisk -a lsilogic -t 0 (Join-Path $dir "$name-system.vmdk") | Out-Null
    & $vdisk -c -s $DataDisk   -a lsilogic -t 0 (Join-Path $dir "$name-data.vmdk")   | Out-Null

    $vhv = if ($NestedVirt) { "TRUE" } else { "FALSE" }
    # MAC statiques (plage VMware 00:50:56:00-3F) : dernier octet = numéro du nœud
    $mac0 = "00:50:56:2A:20:1$n"
    $mac1 = "00:50:56:2A:10:1$n"

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
vhv.enable = "$vhv"
vpmc.enable = "FALSE"
mem.hotadd = "FALSE"
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
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"

scsi0.present = "TRUE"
scsi0.virtualDev = "pvscsi"
scsi0.pciSlotNumber = "224"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "$name-system.vmdk"
scsi0:1.present = "TRUE"
scsi0:1.fileName = "$name-data.vmdk"

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
ethernet0.address = "$mac0"
ethernet0.startConnected = "TRUE"

ethernet1.present = "TRUE"
ethernet1.connectionType = "custom"
ethernet1.vnet = "VMnet10"
ethernet1.virtualDev = "vmxnet3"
ethernet1.pciSlotNumber = "192"
ethernet1.addressType = "static"
ethernet1.address = "$mac1"
ethernet1.startConnected = "TRUE"
"@
    # VMware ne supporte pas le BOM UTF-8 que PowerShell 5 ajoute avec Set-Content
    [IO.File]::WriteAllText($vmx, $vmxContent, (New-Object Text.UTF8Encoding $false))

    Write-Host "Créé : $vmx"
}

Write-Host "`nOuvre les VM dans VMware : Fichier > Ouvrir > $VmRoot\PVE*\PVE*.vmx"
