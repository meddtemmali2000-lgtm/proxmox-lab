#Requires -RunAsAdministrator
# Ajoute une 2e entrée au menu de démarrage Windows, sans hyperviseur Hyper-V :
#   "Windows"                     -> Hyper-V/VBS actif : WSL2 et Docker fonctionnent
#   "Windows - Lab VMware"        -> pas d'hyperviseur : VT-x imbriqué dans VMware (KVM dans Proxmox)
# Au redémarrage, Windows affiche un menu pour choisir.
# Annulation : bcdedit /delete {GUID}  (GUID affiché à la fin du script)

$ErrorActionPreference = "Stop"
$label = "Windows - Lab VMware (sans Hyper-V)"

$existing = bcdedit /enum OSLOADER | Select-String -SimpleMatch $label
if ($existing) { Write-Host "L'entrée '$label' existe déjà."; bcdedit /enum OSLOADER; return }

$out = bcdedit /copy "{current}" /d $label
$guid = [regex]::Match($out, "\{[0-9a-fA-F-]+\}").Value
if (-not $guid) { throw "Impossible de copier l'entrée de démarrage : $out" }

bcdedit /set $guid hypervisorlaunchtype off
bcdedit /timeout 10

Write-Host "`nEntrée créée : $guid"
Write-Host "Au prochain redémarrage, choisis '$label' pour le lab Proxmox."
Read-Host "Appuie sur Entrée pour fermer"
