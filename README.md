# faasd - Lightweight Serverless Setup (bitresearch2006 Edition)

This repository contains a custom installer and configuration for **faasd**, a lightweight implementation of OpenFaaS that uses `containerd` directly instead of Kubernetes. This setup is optimized for single-node deployments, making it ideal for low-cost VPS or edge devices like Raspberry Pi.

## Features of this Setup

* **Lightweight:** Removes the overhead of Kubernetes; runs directly on `containerd`.
* **Multi-Arch:** Supports both **x86_64** (Standard Servers) and **arm64** (Raspberry Pi 3/4).
* **Automated Networking:** Sets up CNI plugins and bridge networking automatically.
* **HTTPS Ready:** Includes optional automatic SSL termination using Caddy.
* **Tooling:** Automatically installs the `faas-cli` client.

## Prerequisites

Before running the installation script, ensure your system meets the following requirements:

* **OS:** Ubuntu 20.04/22.04, Debian 10/11, CentOS 7/8, or Arch Linux.
* **Permissions:** You must have root access (`sudo`).
* **Ports:** Ensure ports `80` and `443` (for Caddy) and `8080` (for OpenFaaS gateway) are open.

## Installation

### 1. Clone the Repository
First, download the repository to your server:

```bash
git clone [https://github.com/bitresearch2006/faasd.git](https://github.com/bitresearch2006/faasd.git)
cd faasd
chmod +x install.sh
2. Run the Installer
Choose one of the two methods below depending on your needs.

Option A: Standard Installation (HTTP only)
Use this for local testing or if you do not have a domain name pointed to the server yet.

Bash

./install.sh
Option B: Production Installation (HTTPS with Caddy)
Use this if you have a domain name (e.g., fns.example.com) pointed to your server's IP. This will install Caddy and automatically provision a Let's Encrypt SSL certificate.

Replace the values below with your actual domain and email:

Bash

export FAASD_DOMAIN="fns.example.com"
export LETSENCRYPT_EMAIL="admin@example.com"

./install.sh
Post-Installation
Once the script finishes successfully, the OpenFaaS services will be running.

1. Retrieve your Password
The installation generates a random secure password for the admin user. Retrieve it using:

Bash

sudo cat /var/lib/faasd/secrets/basic-auth-password
2. Login with faas-cli
The faas-cli is installed automatically. Log in to your new server:

Bash

# If you used Option A (Standard)
export OPENFAAS_URL=[http://127.0.0.1:8080](http://127.0.0.1:8080)

# If you used Option B (HTTPS)
export OPENFAAS_URL=[https://fns.example.com](https://fns.example.com)

# Login
cat /var/lib/faasd/secrets/basic-auth-password | faas-cli login --password-stdin
3. Verify Status
Check that the core services are running:

Bash

sudo systemctl status faasd
sudo systemctl status containerd