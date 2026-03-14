#!/usr/bin/env bash

set -euo pipefail

echo "🧹 Uninstalling FAAS platform..."

############################################
# Stop faasd services
############################################
sudo systemctl stop faasd 2>/dev/null || true
sudo systemctl disable faasd 2>/dev/null || true

sudo systemctl stop faasd-provider 2>/dev/null || true
sudo systemctl disable faasd-provider 2>/dev/null || true

############################################
# Remove faasd binaries
############################################
echo "Removing faasd binaries..."

sudo rm -f /usr/local/bin/faasd
sudo rm -f /usr/local/bin/faas-cli

############################################
# Remove faasd configuration
############################################
echo "Removing faasd configuration..."

sudo rm -rf /var/lib/faasd
sudo rm -rf /etc/faasd

############################################
# Remove temporary install files
############################################
sudo rm -rf /tmp/faasd-install
sudo rm -rf /tmp/faasd-*

############################################
# Stop and remove containerd
############################################
echo "Removing containerd..."

sudo systemctl stop containerd 2>/dev/null || true
sudo systemctl disable containerd 2>/dev/null || true

sudo rm -f /usr/local/bin/containerd
sudo rm -f /usr/local/bin/ctr
sudo rm -f /usr/local/bin/containerd-shim*

############################################
# Remove CNI plugins
############################################
echo "Removing CNI plugins..."

sudo rm -rf /opt/cni

############################################
# Remove arkade
############################################
echo "Removing arkade..."

sudo rm -f /usr/local/bin/arkade

############################################
# Remove Docker registry container
############################################
echo "Removing Docker registry..."

if sudo docker ps -a --format '{{.Names}}' | grep -q '^registry$'; then
  sudo docker rm -f registry || true
fi

############################################
# Remove Docker
############################################
echo "🧹 Removing Docker..."

sudo systemctl stop docker 2>/dev/null || true
sudo systemctl disable docker 2>/dev/null || true
sudo systemctl stop docker.socket 2>/dev/null || true
sudo systemctl disable docker.socket 2>/dev/null || true

# Remove registry container
sudo docker rm -f registry 2>/dev/null || true

# Kill docker daemon if still running
sudo pkill -f dockerd 2>/dev/null || true

# Unmount docker overlay mounts
sudo umount -l /var/lib/docker/overlay2/*/merged 2>/dev/null || true

# Remove docker data
sudo rm -rf /var/lib/docker
sudo rm -rf /etc/docker

# Remove docker package
sudo apt purge -y docker.io 2>/dev/null || true
sudo apt autoremove -y

############################################
# Remove docker group membership
############################################
sudo deluser "$USER" docker 2>/dev/null || true
sudo groupdel docker 2>/dev/null || true

############################################
# Remove sysctl rule added by installer
############################################
echo "Cleaning sysctl configuration..."

sudo sed -i '/net.ipv4.conf.all.forwarding=1/d' /etc/sysctl.conf

############################################
# Reload systemd
############################################
sudo systemctl daemon-reload

echo "✅ Uninstallation completed successfully."

############################################
# Ask for reboot
############################################
read -p "Do you want to restart now to apply changes? [y/N]: " restart_choice

if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
  echo "🔄 Restarting system..."
  sudo reboot
else
  echo "ℹ️ Please reboot or log out later for changes to take effect."
fi