#!/usr/bin/env bash

set -euo pipefail

############################################
# Configuration
############################################
OWNER="bitresearch2006"
REPO="faasd"
ARKADE="/usr/local/bin/arkade"
CONTAINERD_VER="${CONTAINERD_VER:-1.7.27}"
CNI_VERSION="v0.9.1"

TMP_DIR="/tmp/faasd-install"

############################################
# Utility functions
############################################
log() {
  echo "[FAASD-INSTALL] $*"
}

fatal() {
  echo "[ERROR] $*" >&2
  exit 1
}

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

############################################
# Detect sudo
############################################
SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
fi

############################################
# Detect latest release
############################################
get_latest_version() {
  log "Fetching latest version from GitHub API"

  version=$(curl -s https://api.github.com/repos/${OWNER}/${REPO}/releases/latest \
    | grep tag_name \
    | cut -d '"' -f4)

  if [ -z "$version" ]; then
    fatal "Unable to determine latest release version"
  fi

  echo "$version"
}

############################################
# System validation
############################################
verify_system() {

  arch=$(uname -m)

  if [ "$arch" = "armv7l" ]; then
    fatal "faasd requires a 64-bit OS"
  fi

  if [ ! -d /run/systemd ]; then
    fatal "systemd is required"
  fi

}

############################################
# Package manager detection
############################################
has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_required_packages() {

  log "Installing required packages"

  if has_cmd apt-get; then

    $SUDO apt-get update -y

    $SUDO apt-get install -y \
      curl \
      ca-certificates \
      runc \
      bridge-utils \
      iptables

  elif has_cmd dnf; then

    $SUDO dnf install -y \
      --allowerasing \
      --setopt=install_weak_deps=False \
      curl runc iptables-services bridge-utils

  elif has_cmd pacman; then

    $SUDO pacman -Syy
    $SUDO pacman -Sy --noconfirm curl runc bridge-utils

  else

    fatal "Unsupported OS package manager"

  fi

}

############################################
# Install arkade
############################################
install_arkade() {

  if has_cmd arkade; then
    log "Arkade already installed"
    return
  fi

  log "Installing arkade"

  curl -sLS https://get.arkade.dev | $SUDO sh

}

############################################
# Install CNI plugins
############################################
install_cni_plugins() {

  log "Installing CNI plugins"

  $SUDO $ARKADE system install cni \
    --version ${CNI_VERSION} \
    --path /opt/cni/bin \
    --progress=false

}

############################################
# Install containerd
############################################
install_containerd() {

  if systemctl is-active --quiet containerd; then
    log "containerd already running"
    return
  fi

  log "Installing containerd"

  $SUDO systemctl unmask containerd || true

  $SUDO $ARKADE system install containerd \
    --systemd \
    --version v${CONTAINERD_VER} \
    --progress=false

  log "Waiting for containerd"

  sleep 3

  if ! systemctl is-active --quiet containerd; then
    fatal "containerd failed to start"
  fi

}

############################################
# Install faas-cli
############################################
install_faas_cli() {

  if has_cmd faas-cli; then
    log "faas-cli already installed"
    return
  fi

  log "Installing faas-cli"

  $ARKADE get --progress=false faas-cli

  $SUDO install -m 755 $HOME/.arkade/bin/faas-cli /usr/local/bin/

}

############################################
# Install faasd
############################################
install_faasd() {

  if has_cmd faasd; then
    log "faasd already installed"
    return
  fi

  version=$(get_latest_version)

  log "Installing faasd $version"

  mkdir -p "$TMP_DIR/hack"
  cd "$TMP_DIR"

  arch=$(uname -m)

  case $arch in

  x86_64|amd64)
    suffix=""
    ;;

  aarch64)
    suffix="-arm64"
    ;;

  *)
    fatal "Unsupported architecture $arch"
    ;;

  esac

  $SUDO curl -fSL \
    "https://github.com/${OWNER}/${REPO}/releases/download/${version}/faasd${suffix}" \
    -o /usr/local/bin/faasd

  $SUDO chmod +x /usr/local/bin/faasd

  curl -fSL \
    "https://raw.githubusercontent.com/${OWNER}/${REPO}/${version}/docker-compose.yaml" \
    -o docker-compose.yaml

  curl -fSL \
    "https://raw.githubusercontent.com/${OWNER}/${REPO}/${version}/prometheus.yml" \
    -o prometheus.yml

  curl -fSL \
    "https://raw.githubusercontent.com/${OWNER}/${REPO}/${version}/resolv.conf" \
    -o resolv.conf

  curl -fSL \
    "https://raw.githubusercontent.com/${OWNER}/${REPO}/${version}/hack/faasd-provider.service" \
    -o hack/faasd-provider.service

  curl -fSL \
    "https://raw.githubusercontent.com/${OWNER}/${REPO}/${version}/hack/faasd.service" \
    -o hack/faasd.service

  $SUDO /usr/local/bin/faasd install

}


############################################
# Install docker
############################################
install_docker() {

  if has_cmd docker; then
    log "Docker already installed"
    return
  fi

  log "Installing docker.io"

  $SUDO apt-get update
  $SUDO apt-get install -y docker.io

  $SUDO systemctl enable docker
  $SUDO systemctl start docker

  $SUDO usermod -aG docker $USER

  log "Docker installation completed"

}

############################################
# set docker registery to run in locahost
############################################
set_docker_registry() {

  if docker ps -a --format '{{.Names}}' | grep -q '^registry$'; then
    log "Docker registry already exists"
    return
  fi

  log "Starting local Docker registry"

  $SUDO docker run -d \
    -p 5000:5000 \
    --restart=always \
    --name registry \
    registry:2
}

############################################
# Main
############################################
main() {

  verify_system

  install_required_packages

  $SUDO sysctl -w net.ipv4.conf.all.forwarding=1

  grep -q "net.ipv4.conf.all.forwarding=1" /etc/sysctl.conf || \
  echo "net.ipv4.conf.all.forwarding=1" | $SUDO tee -a /etc/sysctl.conf

  install_arkade

  install_cni_plugins

  install_containerd

  install_faas_cli

  install_faasd
  
  install_docker
  
  set_docker_registry

  log "Installation completed successfully"

}

main
