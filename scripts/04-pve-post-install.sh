#!/usr/bin/env bash
# Post-installation d'un nœud du lab (Proxmox VE 9 / Debian trixie).
# Usage : bash 04-pve-post-install.sh <numéro du nœud 1|2|3>
set -euo pipefail

N="${1:?Usage: $0 <1|2|3>}"
CLUSTER_IF="nic1"
CLUSTER_IP="10.10.10.1${N}/24"

# Réseau cluster (VMnet10)
if ! grep -q "iface ${CLUSTER_IF}" /etc/network/interfaces; then
    cat >> /etc/network/interfaces <<EOF

auto ${CLUSTER_IF}
iface ${CLUSTER_IF} inet static
    address ${CLUSTER_IP}
#Cluster corosync / migration (VMnet10)
EOF
fi
ifreload -a

# Résolution des noms entre nœuds
sed -i '/lab\.local/d' /etc/hosts
cat >> /etc/hosts <<EOF
192.168.20.11 pve1.lab.local pve1
192.168.20.12 pve2.lab.local pve2
192.168.20.13 pve3.lab.local pve3
EOF

# Dépôts : désactive enterprise (abonnement payant), active no-subscription
for f in /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/ceph.sources; do
    [ -f "$f" ] && { grep -q '^Enabled:' "$f" && sed -i 's/^Enabled:.*/Enabled: no/' "$f" || echo "Enabled: no" >> "$f"; }
done
cat > /etc/apt/sources.list.d/proxmox.sources <<EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade

timedatectl set-ntp true

echo "=== $(hostname -f) prêt"
ip -br addr show vmbr0
ip -br addr show "${CLUSTER_IF}"
