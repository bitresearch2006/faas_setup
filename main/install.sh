#!/bin/bash

set -euo pipefail

export OWNER="bitresearch2006"
export REPO="faasd"

# On CentOS /usr/local/bin is not included in the PATH when using sudo. 
# Running arkade with sudo on CentOS requires the full path
# to the arkade binary. 
export ARKADE=/usr/local/bin/arkade

# When running as a startup script (cloud-init), the HOME variable is not always set.
# As it is required for arkade to properly download tools, 
# set the variable to /usr/local so arkade will download binaries to /usr/local/.arkade
if [ -z "${HOME}" ]; then
  export HOME=/usr/local
fi

############################################
# Utility functions
############################################

fatal() {
  echo "ERROR: $1"
  exit 1
}

SUDO=sudo
if [ "$(id -u)" -eq 0 ]; then
  SUDO=
fi

############################################
# Detect latest release
############################################

echo "Finding latest version from GitHub"

version=$(curl -sI https://github.com/$OWNER/$REPO/releases/latest \
 | grep -i "location:" \
 | awk -F"/" '{print $NF}' \
 | tr -d '\r')

echo "Latest version: $version"

if [ -z "$version" ]; then
  fatal "Failed while attempting to get latest version"
fi

############################################
# System verification
############################################

verify_system() {

  arch=$(uname -m)

  if [ "$arch" == "armv7l" ]; then
    fatal "faasd requires a 64-bit OS"
  fi

  if ! [ -d /run/systemd ]; then
    fatal "systemd not detected"
  fi
}

############################################
# Package manager detection
############################################

has_dnf() { command -v dnf >/dev/null 2>&1; }
has_apt_get() { command -v apt-get >/dev/null 2>&1; }
has_pacman() { command -v pacman >/dev/null 2>&1; }

############################################
# Install base dependencies
############################################

install_required_packages() {

  if has_apt_get; then
    # Debian bullseye is missing iptables. Added to required packages
    # to get it working in raspberry pi. No such known issues in
    # other distros. Hence, adding only to this block.
    # reference: https://github.com/openfaas/faasd/pull/237
    $SUDO apt-get update -y
    $SUDO apt-get install -y curl runc bridge-utils iptables

  elif has_dnf; then
    $SUDO dnf install -y \
      --allowerasing \
      --setopt=install_weak_deps=False \
      curl runc iptables-services bridge-utils

  elif has_pacman; then
    $SUDO pacman -Syy
    $SUDO pacman -Sy curl runc bridge-utils

  else
    fatal "Unsupported package manager"
  fi
}

############################################
# Install Docker (needed for function build)
############################################

install_docker() {

  echo "Installing Docker..."

  sudo apt-get update
  sudo apt-get install -y docker.io

  sudo systemctl enable docker
  sudo systemctl start docker

  sudo usermod -aG docker $USER

}

############################################
# Install Docker registry (Access localhost:5000)
############################################
install_registry() {

  echo "Setting up local Docker registry..."

  if sudo docker ps -a --format '{{.Names}}' | grep -q '^registry$'; then
      echo "Registry already exists"
      return
  fi

  sudo docker run -d \
      -p 5000:5000 \
      --restart=always \
      --name registry \
      registry:2
}


############################################
# Install Arkade
############################################

install_arkade(){

  if ! command -v arkade >/dev/null 2>&1; then
    echo "Installing arkade..."
    curl -sLS https://get.arkade.dev | $SUDO sh
  fi

  arkade version
}

############################################
# Install CNI
############################################

install_cni_plugins() {

  cni_version=v0.9.1

  $SUDO $ARKADE system install cni \
    --version ${cni_version} \
    --path /opt/cni/bin \
    --progress=false
}

############################################
# Install containerd
############################################

install_containerd() {

  CONTAINERD_VER=1.7.27

  $SUDO systemctl unmask containerd || true

  $SUDO $ARKADE system install containerd \
    --systemd \
    --version v${CONTAINERD_VER} \
    --progress=false

  sleep 5
}

############################################
# Install faasd
############################################

install_faasd() {
  arch=$(uname -m)
  case $arch in
  x86_64 | amd64)
    suffix=""
    ;;
  aarch64)
    suffix=-arm64
    ;;
  *)
    echo "Unsupported architecture $arch"
    exit 1
    ;;
  esac

  $SUDO curl -fSLs "https://github.com/$OWNER/$REPO/releases/download/${version}/faasd${suffix}" --output "/usr/local/bin/faasd"
  $SUDO chmod a+x "/usr/local/bin/faasd"

  mkdir -p /tmp/faasd-${version}-installation/hack
  cd /tmp/faasd-${version}-installation
  $SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${version}/docker-compose.yaml" --output "docker-compose.yaml"
  $SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${version}/prometheus.yml" --output "prometheus.yml"
  $SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${version}/resolv.conf" --output "resolv.conf"
  $SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${version}/hack/faasd-provider.service" --output "hack/faasd-provider.service"
  $SUDO curl -fSLs "https://raw.githubusercontent.com/$OWNER/$REPO/${version}/hack/faasd.service" --output "hack/faasd.service"
  $SUDO /usr/local/bin/faasd install
}


############################################
# Install faas-cli
############################################

install_faas_cli() {
  arkade get --progress=false faas-cli
  $SUDO install -m 755 $HOME/.arkade/bin/faas-cli /usr/local/bin/
}


############################################
# Enable networking
############################################

enable_ip_forward() {

  $SUDO sysctl -w net.ipv4.conf.all.forwarding=1

  if ! grep -q "net.ipv4.conf.all.forwarding=1" /etc/sysctl.conf; then
    echo "net.ipv4.conf.all.forwarding=1" | $SUDO tee -a /etc/sysctl.conf
  fi
}

############################################
# Enable services
############################################

enable_services() {

  echo "Enabling services..."

  $SUDO systemctl daemon-reload

  $SUDO systemctl enable containerd
  $SUDO systemctl start containerd

  $SUDO systemctl enable faasd
  $SUDO systemctl start faasd

  if command -v docker >/dev/null 2>&1; then
    $SUDO systemctl enable docker
  fi
}

############################################
# Main execution
############################################

verify_system
install_required_packages
install_docker
install_registry
enable_ip_forward
install_arkade
install_cni_plugins
install_containerd
install_faas_cli
install_faasd
enable_services

echo "--------------------------------------"
echo "FAAS platform installed successfully"
echo "--------------------------------------"
