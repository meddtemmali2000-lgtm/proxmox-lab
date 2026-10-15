# Proxmox Lab – cluster 3 nœuds sur VMware Workstation

Lab Proxmox VE 9 à 3 nœuds (PVE1, PVE2, PVE3) en cluster, virtualisé dans VMware Workstation 17 sur un PC Windows.

**Prérequis** : Windows 10/11, VMware Workstation 17.x, 32 Go de RAM, ~150 Go libres, ISO Proxmox VE 9
(par défaut dans `%USERPROFILE%\Documents\images iso\`).

**Étapes**

1. `scripts/01-setup-vmware-network.ps1` (admin) : réseaux VMware
2. `scripts/02-create-pve-vms.ps1` : création des 3 VM
3. Installation de Proxmox sur chaque VM (voir plus bas)
4. `scripts/04-pve-post-install.sh` sur chaque nœud : réseau cluster, `/etc/hosts`, dépôts, mise à jour
5. Création du cluster avec `pvecm`

## Réseau

Le lab est indépendant du Wi-Fi : tout passe par le NAT VMware. Si le PC change de réseau, les IP du lab ne changent pas.

| Réseau  | Type VMware | Sous-réseau      | Passerelle   | IP du PC hôte | Rôle                                   |
|---------|-------------|------------------|--------------|---------------|----------------------------------------|
| VMnet8  | NAT         | 192.168.20.0/24  | 192.168.20.2 | 192.168.20.1  | Gestion, SSH, Internet, VM internes    |
| VMnet10 | Host-only   | 10.10.10.0/24    | aucune       | 10.10.10.1    | Corosync (cluster), migration          |

Plan d'adressage sur VMnet8 :

- `192.168.20.11-13` : PVE1, PVE2, PVE3
- `192.168.20.100-127` : VM/CT internes avec IP fixe
- `192.168.20.128-254` : DHCP VMware (VM internes en DHCP)

## Nœuds

| Nœud | FQDN            | nic0 (VMnet8)  | nic1 (VMnet10) | Ressources                                  |
|------|-----------------|------------------|------------------|---------------------------------------------|
| PVE1 | pve1.lab.local  | 192.168.20.11/24 | 10.10.10.11/24   | 8 Go RAM, 4 vCPU, 40 Go système + 30 Go data |
| PVE2 | pve2.lab.local  | 192.168.20.12/24 | 10.10.10.12/24   | idem                                        |
| PVE3 | pve3.lab.local  | 192.168.20.13/24 | 10.10.10.13/24   | idem                                        |
| PBS  | pbs.lab.local   | 192.168.20.14/24 | –                | 2 Go RAM, 2 vCPU, 32 Go système + 64 Go datastore |

VM VMware : `Documents\Virtual Machines\proxmox-lab\PVE{1,2,3}\`

Proxmox VE 9 fige les noms des cartes réseau en `nic0`, `nic1`… (et non `ens160`, `ens192`).
Correspondance grâce aux MAC fixées dans les `.vmx` : `00:50:56:2a:20:1N` = `nic0` (VMnet8), `00:50:56:2a:10:1N` = `nic1` (VMnet10).

## Scripts

| Script                               | Admin | Rôle                                                        |
|--------------------------------------|-------|-------------------------------------------------------------|
| `scripts/01-setup-vmware-network.ps1`| oui   | Configure VMnet8 (NAT) et crée VMnet10 (host-only)          |
| `scripts/02-create-pve-vms.ps1`      | non   | Crée les VM PVE1-3 (`-NestedVirt $false` si Hyper-V actif)  |
| `scripts/03-hyperv-boot-toggle.ps1`  | oui   | Ajoute une entrée de démarrage Windows sans Hyper-V         |
| `scripts/04-pve-post-install.sh`     | root  | Post-installation d'un nœud : `bash 04-pve-post-install.sh N` |
| `scripts/06-create-pbs-vm.ps1`       | non   | Crée la VM Proxmox Backup Server                            |

## Hyper-V / WSL

WSL2 a besoin de Hyper-V, et VMware ne peut pas faire de virtualisation imbriquée (KVM dans Proxmox) quand Hyper-V est actif.

**Choix actuel : Hyper-V et WSL2 restent actifs**, les VM PVE ont `vhv.enable = "FALSE"`.
Conséquences dans Proxmox :

- cluster, stockage, réseau, conteneurs LXC : fonctionnent normalement
- VM QEMU : décocher *Options > KVM hardware virtualization*, sinon elles ne démarrent pas (émulation lente)

Pour avoir KVM plus tard, `03-hyperv-boot-toggle.ps1` ajoute un choix au démarrage :

- **Windows** : Hyper-V actif, WSL2 fonctionne (les VM PVE ne démarrent pas avec `vhv.enable = TRUE`)
- **Windows - Lab VMware (sans Hyper-V)** : lab Proxmox complet, WSL2 indisponible

## Installation Proxmox (pour chaque nœud)

Dans l'installateur graphique :

- Disque cible : `sda` (40 Go), laisser `sdb` libre
- Hostname : `pveN.lab.local`
- Interface de gestion : `nic0`, IP `192.168.20.1N/24`, passerelle `192.168.20.2`, DNS `192.168.20.2`

## Post-installation

Méthode automatique, depuis le PC (clé SSH installée sur les nœuds) :

```powershell
scp scripts/04-pve-post-install.sh root@192.168.20.11:/root/
ssh root@192.168.20.11 "bash /root/04-pve-post-install.sh 1"   # 2 pour pve2, 3 pour pve3
```

Le script fait l'équivalent des étapes manuelles ci-dessous, puis désactive les dépôts `enterprise`
(abonnement payant, erreur 401) et active `pve-no-subscription`, et met le système à jour.
Redémarrer ensuite le nœud si un nouveau noyau a été installé.

Méthode manuelle : ajouter le réseau cluster dans `/etc/network/interfaces`, en supprimant la ligne
`iface nic1 inet manual` laissée par l'installateur :

```
auto nic1
iface nic1 inet static
    address 10.10.10.1N/24
```

puis `ifreload -a`. Dans `/etc/hosts` sur chaque nœud :

```
192.168.20.11 pve1.lab.local pve1
192.168.20.12 pve2.lab.local pve2
192.168.20.13 pve3.lab.local pve3
```

SSH depuis le PC : `ssh root@192.168.20.11` – interface web : https://192.168.20.11:8006

## Cluster

```bash
# sur pve1
pvecm create lab-cluster --link0 10.10.10.11 --link1 192.168.20.11
# sur pve2 (et pve3 avec .13)
pvecm add 10.10.10.11 --link0 10.10.10.12 --link1 192.168.20.12
pvecm status
```

Résultat attendu : `Total votes: 3`, `Quorate: Yes`. Avec 3 nœuds, le cluster garde le quorum (2/3) si un nœud tombe.
Un nœud qui rejoint le cluster ne doit contenir aucune VM ni conteneur.

## VM internes

Les VM créées dans Proxmox se branchent sur `vmbr0` (pont sur `nic0`). Elles sont donc dans `192.168.20.0/24`,
sortent sur Internet par `192.168.20.2` et sont joignables en SSH directement depuis le PC.
