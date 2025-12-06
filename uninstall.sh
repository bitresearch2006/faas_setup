
#!/bin/bash

set -e

echo "🧹 Uninstalling faasd and related components..."

# Stop and disable faasd service
sudo systemctl stop faasd || true
sudo systemctl disable faasd || true

# Stop and disable faasd-provider service
sudo systemctl stop faasd-provider || true
sudo systemctl disable faasd-provider || true

# Remove faasd and faas-cli binaries
sudo rm -f /usr/local/bin/faasd
sudo rm -f /usr/local/bin/faas-cli

# Remove faasd configuration and data directories
sudo rm -rf /var/lib/faasd
sudo rm -rf /etc/faasd
sudo rm -rf /tmp/faasd-*

# Optionally remove containerd and CNI plugins
sudo systemctl stop containerd || true
sudo systemctl disable containerd || true
sudo rm -f /usr/local/bin/containerd
sudo rm -f /usr/local/bin/ctr
sudo rm -rf /opt/cni/bin

# Remove arkade binary
sudo rm -f /usr/local/bin/arkade


# Docker cleanup
echo "🧹 Removing Docker..."
sudo systemctl stop docker || true
sudo systemctl disable docker || true
sudo systemctl stop docker.socket || true
sudo systemctl disable docker.socket || true
sudo pkill -f dockerd || true
mount | grep /var/lib/docker | awk '{print $3}' | xargs -r sudo umount -l || true
sudo rm -rf /var/lib/docker || echo "⚠️ Could not remove /var/lib/docker. It may still be in use."
sudo rm -rf /etc/docker
sudo apt purge -y docker.io docker-ce docker-ce-cli containerd.io || true
sudo apt autoremove -y
# Explicitly remove current user from the docker group (reverses setup script action)
sudo deluser "$USER" docker || true
sudo groupdel docker || true
echo "✅ Uninstallation complete."

read -p "Do you want to restart now to apply the change? [y/N]: " restart_choice
if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
  echo "🔄 Restarting system..."
  sudo reboot
else
  echo "⏳ Please remember to log out and log back in later."
fi
