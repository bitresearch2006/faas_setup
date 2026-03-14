# faasd - Lightweight Serverless Setup (bitresearch2006 Edition)

This repository provides an automated installer for **faasd**, a lightweight serverless platform based on OpenFaaS that runs directly on **containerd** without Kubernetes.

This setup also installs **Docker and a local Docker registry** to simplify building and deploying functions.

The installer is designed for **single-node deployments**, making it ideal for:

- Development environments
- Edge devices
- Small VPS servers
- Raspberry Pi

---

# Features

This setup automatically installs and configures:

- **faasd** (OpenFaaS without Kubernetes)
- **containerd** container runtime
- **CNI networking plugins**
- **faas-cli**
- **Docker**
- **Local Docker registry (localhost:5000)**

Benefits:

- Lightweight
- No Kubernetes required
- Supports **x86_64** and **ARM64**
- Easy function deployment workflow
- Automated installation

---

# Supported Platforms

Tested on:

- Ubuntu 20.04 / 22.04
- Debian 11 / 12

Architecture:

- x86_64
- ARM64 (Raspberry Pi 4 / 5)

---

# Requirements

Before installing:

- Root or sudo access
- Internet connectivity
- Ports available:

| Port | Purpose |
|-----|------|
| 8080 | OpenFaaS gateway |
| 5000 | Local Docker registry |

---

# Installation

Clone the repository:

```bash
git clone https://github.com/bitresearch2006/faasd.git
cd faasd
chmod +x install.sh

Run the installer:

./install.sh

The installer will automatically install:

arkade

CNI plugins

containerd

faas-cli

faasd

Docker

Docker registry

After Installation
Get the OpenFaaS password

The installer creates a secure password.

Retrieve it with:

sudo cat /var/lib/faasd/secrets/basic-auth-password
Login using faas-cli

Set the OpenFaaS gateway:

export OPENFAAS_URL=http://127.0.0.1:8080

Login:

cat /var/lib/faasd/secrets/basic-auth-password | faas-cli login --password-stdin
Verify Installation

Check services:

sudo systemctl status faasd
sudo systemctl status containerd
sudo systemctl status docker

You can also verify the registry:

docker ps

You should see:

registry
Deploying Functions

Example workflow:

Build function image
docker build -t hello-function .
Tag image for local registry
docker tag hello-function localhost:5000/hello-function
Push image to registry
docker push localhost:5000/hello-function
Deploy using faas-cli
faas-cli deploy --image localhost:5000/hello-function
Uninstall

To remove everything installed by this repository:

chmod +x uninstall.sh
./uninstall.sh

The uninstaller removes:

faasd

faas-cli

containerd

CNI plugins

arkade

Docker

local Docker registry

Source: 

uninstall

Architecture

The installed platform looks like this:

Developer
   │
   │ docker build
   ▼
Docker
   │
   │ docker push
   ▼
Local Registry (localhost:5000)
   │
   │ faas-cli deploy
   ▼
faasd
   │
containerd
   │
CNI networking
Notes

The Docker registry is ephemeral.

If the container is removed, stored images will be lost.

This is intentional to keep the environment lightweight.

Repository

GitHub:

https://github.com/bitresearch2006/faasd

