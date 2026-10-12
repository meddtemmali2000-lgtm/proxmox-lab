#Requires -RunAsAdministrator
# Configure les réseaux VMware Workstation pour le lab Proxmox :
#   VMnet8  (NAT)       192.168.20.0/24  gw 192.168.20.2  -> gestion, SSH, Internet, VM internes
#   VMnet10 (host-only) 10.10.10.0/24    pas de DHCP      -> corosync / migration du cluster

$ErrorActionPreference = "Stop"
$vnetlib = "C:\Program Files (x86)\VMware\VMware Workstation\vnetlib64.exe"

function Invoke-Vnetlib {
    Write-Host "vnetlib -- $($args -join ' ')"
    # vnetlib64 est une appli GUI : sans -Wait, PowerShell n'attend pas la fin de la commande
    $p = Start-Process -FilePath $vnetlib -ArgumentList (@("--") + $args) -Wait -PassThru -WindowStyle Hidden
    Write-Host "  -> code $($p.ExitCode)"
}

Invoke-Vnetlib stop dhcp
Invoke-Vnetlib stop nat

# VMnet8 : on garde le sous-réseau existant (192.168.20.0/24), DHCP .128-.254 pour les VM internes
Invoke-Vnetlib set vnet vmnet8 mask 255.255.255.0
Invoke-Vnetlib set vnet vmnet8 addr 192.168.20.0
Invoke-Vnetlib set adapter vmnet8 addr 192.168.20.1
Invoke-Vnetlib set nat vmnet8 internalipaddr 192.168.20.2
Invoke-Vnetlib update dhcp vmnet8
Invoke-Vnetlib update nat vmnet8
Invoke-Vnetlib update adapter vmnet8

# VMnet10 : réseau privé du cluster, le PC hôte a 10.10.10.1
if (-not (Get-NetAdapter -Name "VMware Network Adapter VMnet10" -ErrorAction SilentlyContinue)) {
    Invoke-Vnetlib add adapter vmnet10
}
Invoke-Vnetlib set vnet vmnet10 mask 255.255.255.0
Invoke-Vnetlib set vnet vmnet10 addr 10.10.10.0
Invoke-Vnetlib set adapter vmnet10 addr 10.10.10.1
Invoke-Vnetlib remove dhcp vmnet10
Invoke-Vnetlib update adapter vmnet10

Invoke-Vnetlib start dhcp
Invoke-Vnetlib start nat

Write-Host "`nÉtat des cartes VMware sur l'hôte :"
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object InterfaceAlias -like "VMware*" |
    Format-Table InterfaceAlias, IPAddress, PrefixLength -AutoSize
