#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

LOG_FILE="/var/log/ec2-bootstrap-tools.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting EC2 bootstrap at $(date)"

# ------------------------------------------------------------
# Detect OS/user/architecture
# ------------------------------------------------------------
. /etc/os-release

OS_ID="${ID}"
OS_CODENAME="${VERSION_CODENAME:-}"
DEFAULT_USER="ubuntu"

if id ec2-user >/dev/null 2>&1; then
  DEFAULT_USER="ec2-user"
fi

ARCH="$(dpkg --print-architecture)"

case "$ARCH" in
  amd64)
    K8S_ARCH="amd64"
    KIND_ARCH="amd64"
    ;;
  arm64)
    K8S_ARCH="arm64"
    KIND_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "OS: ${PRETTY_NAME}"
echo "Codename: ${OS_CODENAME}"
echo "Architecture: ${ARCH}"
echo "Default user: ${DEFAULT_USER}"

if [ "$OS_ID" != "ubuntu" ]; then
  echo "This script is intended for Ubuntu only."
  exit 1
fi

# ------------------------------------------------------------
# Kernel limits for file watchers
# ------------------------------------------------------------
cat >/etc/sysctl.d/99-inotify.conf <<EOF
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=1024
fs.inotify.max_queued_events=32768
EOF

sysctl --load=/etc/sysctl.d/99-inotify.conf

# ------------------------------------------------------------
# Create apex-sync operator user
# ------------------------------------------------------------
APEX_USER="apex-sync"
APEX_HOME="/home/${APEX_USER}"

if ! id "$APEX_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$APEX_USER"
  echo "Created user: ${APEX_USER}"
else
  echo "User already exists: ${APEX_USER}"
fi

# Give passwordless sudo privileges.
usermod -aG sudo "$APEX_USER"
cat >"/etc/sudoers.d/${APEX_USER}" <<EOF
${APEX_USER} ALL=(ALL) NOPASSWD:ALL
EOF
chmod 0440 "/etc/sudoers.d/${APEX_USER}"

# Reuse the default EC2 user's authorized_keys so you can SSH as apex-sync.
mkdir -p "${APEX_HOME}/.ssh"

if [ -f "/home/${DEFAULT_USER}/.ssh/authorized_keys" ]; then
  cp "/home/${DEFAULT_USER}/.ssh/authorized_keys" "${APEX_HOME}/.ssh/authorized_keys"
fi

chown -R "${APEX_USER}:${APEX_USER}" "${APEX_HOME}/.ssh"
chmod 700 "${APEX_HOME}/.ssh"
chmod 600 "${APEX_HOME}/.ssh/authorized_keys" || true

echo "Configured sudo and SSH access for user: ${APEX_USER}"

# ------------------------------------------------------------
# Base packages
# ------------------------------------------------------------
apt-get update -y
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  unzip \
  software-properties-common \
  apt-transport-https \
  haproxy \
  git \
  jq \
  yq \
  python3 \
  python3-kubernetes \
  python3-pip \
  python3-venv

# ------------------------------------------------------------
# Docker latest
# ------------------------------------------------------------
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

# Use Ubuntu codename first. If Docker repo does not support 26.04 yet,
# fallback to 24.04 noble.
DOCKER_CODENAME="$OS_CODENAME"

echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${DOCKER_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

if ! apt-get update -y; then
  echo "Docker repo does not support ${DOCKER_CODENAME} yet. Falling back to noble."
  DOCKER_CODENAME="noble"

  echo \
    "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    ${DOCKER_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
fi

apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable docker
systemctl start docker

# ------------------------------------------------------------
# Docker permissions
# ------------------------------------------------------------
groupadd -f docker

usermod -aG docker "$DEFAULT_USER" || true
usermod -aG docker "$APEX_USER"

chown root:docker /var/run/docker.sock || true
chmod 660 /var/run/docker.sock || true

echo "Docker group configured:"
id "$DEFAULT_USER" || true
id "$APEX_USER"
ls -la /var/run/docker.sock || true

# ------------------------------------------------------------
# Terraform latest
# ------------------------------------------------------------
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

HASHICORP_CODENAME="$OS_CODENAME"

echo \
  "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \
  ${HASHICORP_CODENAME} main" \
  > /etc/apt/sources.list.d/hashicorp.list

if ! apt-get update -y; then
  echo "HashiCorp repo does not support ${HASHICORP_CODENAME} yet. Falling back to noble."
  HASHICORP_CODENAME="noble"

  echo \
    "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \
    ${HASHICORP_CODENAME} main" \
    > /etc/apt/sources.list.d/hashicorp.list

  apt-get update -y
fi

apt-get install -y terraform

# ------------------------------------------------------------
# Ansible latest
# ------------------------------------------------------------
# First try the official Ubuntu/Ansible PPA method.
# If the PPA does not support Ubuntu 26.04 yet, fallback to pipx.
if add-apt-repository --yes --update ppa:ansible/ansible; then
  apt-get install -y ansible
else
  echo "Ansible PPA failed. Installing Ansible with pipx fallback."

  apt-get install -y pipx
  pipx ensurepath

  PIPX_BIN="/root/.local/bin/pipx"
  if [ ! -x "$PIPX_BIN" ]; then
    PIPX_BIN="$(command -v pipx)"
  fi

  "$PIPX_BIN" install --include-deps ansible

  ln -sf /root/.local/bin/ansible /usr/local/bin/ansible
  ln -sf /root/.local/bin/ansible-playbook /usr/local/bin/ansible-playbook
fi

# ------------------------------------------------------------
# kubectl latest stable
# ------------------------------------------------------------
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

curl -L -o /tmp/kubectl \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${K8S_ARCH}/kubectl"

install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

# ------------------------------------------------------------
# kind latest
# ------------------------------------------------------------
KIND_VERSION="$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r '.tag_name')"

curl -L -o /tmp/kind \
  "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${KIND_ARCH}"

install -o root -g root -m 0755 /tmp/kind /usr/local/bin/kind
rm -f /tmp/kind

# ------------------------------------------------------------
# Clone apex-sync repository
# ------------------------------------------------------------
REPO_URL="https://github.com/KhaledSaiidi/apex-sync.git"
REPO_DIR="/home/${APEX_USER}/apex-sync"

if [ ! -d "$REPO_DIR/.git" ]; then
  rm -rf "$REPO_DIR"
  sudo -u "$APEX_USER" git clone "$REPO_URL" "$REPO_DIR"
  chown -R "${APEX_USER}:${APEX_USER}" "$REPO_DIR"
else
  echo "Repository already exists at ${REPO_DIR}, pulling latest changes."
  sudo -u "$APEX_USER" git -C "$REPO_DIR" pull --ff-only || true
  chown -R "${APEX_USER}:${APEX_USER}" "$REPO_DIR"
fi

# ------------------------------------------------------------
# Configure HAProxy public gateway
# ------------------------------------------------------------
HAPROXY_SOURCE_CFG="${REPO_DIR}/scripts/haproxy-public-gateway.cfg"
HAPROXY_TARGET_CFG="/etc/haproxy/haproxy.cfg"

if [ ! -f "$HAPROXY_SOURCE_CFG" ]; then
  echo "HAProxy config file not found: $HAPROXY_SOURCE_CFG"
  exit 1
fi

cat "$HAPROXY_SOURCE_CFG" > "$HAPROXY_TARGET_CFG"

haproxy -c -f "$HAPROXY_TARGET_CFG"

systemctl enable haproxy
systemctl restart haproxy

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------
echo ""
echo "Installed versions:"
echo "-------------------"

git --version
docker --version
docker compose version
terraform version
ansible --version | head -n 1
haproxy -v
yq --version
kubectl version --client=true
kind version

echo ""
echo "Bootstrap completed successfully at $(date)"
echo "Log file: $LOG_FILE"
