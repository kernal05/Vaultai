#!/usr/bin/env bash
# Creates a dedicated, non-root user that owns and deploys VaultAI.
# Run once as root. After this, deployment never needs the shared
# root password again — Jenkins builds/deploys as this user instead.
set -euo pipefail

SERVICE_USER="vaultai"

echo "== Creating dedicated service user: $SERVICE_USER =="

if id "$SERVICE_USER" &>/dev/null; then
  echo "User $SERVICE_USER already exists, skipping creation"
else
  useradd -m -s /bin/bash "$SERVICE_USER"
  echo "Created user $SERVICE_USER"
fi

# Docker group membership so it can run docker/compose without sudo/root
usermod -aG docker "$SERVICE_USER"

# Own and lock down the project directory — 750 means only this user
# (and root, unavoidably) can read/enter it. Others get nothing.
mkdir -p /opt/vaultai
chown -R "$SERVICE_USER:$SERVICE_USER" /opt/vaultai
chmod 750 /opt/vaultai

# Generate a dedicated SSH key pair FOR JENKINS to use — separate from
# anyone's personal login, separate from the shared root password.
sudo -u "$SERVICE_USER" mkdir -p /home/$SERVICE_USER/.ssh
sudo -u "$SERVICE_USER" chmod 700 /home/$SERVICE_USER/.ssh

if [ ! -f "/home/$SERVICE_USER/.ssh/id_ed25519" ]; then
  sudo -u "$SERVICE_USER" ssh-keygen -t ed25519 -N "" \
    -f "/home/$SERVICE_USER/.ssh/id_ed25519" -C "jenkins-vaultai-deploy"
fi

sudo -u "$SERVICE_USER" bash -c "cat /home/$SERVICE_USER/.ssh/id_ed25519.pub >> /home/$SERVICE_USER/.ssh/authorized_keys"
sudo -u "$SERVICE_USER" chmod 600 /home/$SERVICE_USER/.ssh/authorized_keys

echo ""
echo "Done. Deployment now runs as '$SERVICE_USER', not root."
echo ""
echo "Private key to give to Jenkins (as a credential, NOT committed to git):"
echo "  /home/$SERVICE_USER/.ssh/id_ed25519"
echo ""
echo "Copy its contents into Jenkins: Manage Jenkins > Credentials >"
echo "  (vaultai folder) > Add Credential > SSH Username with private key"
echo "  Username: $SERVICE_USER"
