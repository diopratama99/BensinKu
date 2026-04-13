#!/usr/bin/env bash
set -euo pipefail

# Installs Docker Engine + Compose plugin on Ubuntu/Debian.
# Run as a user with sudo privileges.

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker

# Optional: allow current user to run docker without sudo (requires re-login)
sudo usermod -aG docker "$USER"

echo "Docker installed. Log out/in to use docker without sudo.";
docker --version
docker compose version
