## For teststing on ec2 instances. This script will be used as user data for the EC2 instance. OS: Ubuntu 26.04 LTS
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
  git \
  jq \
  python3 \
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

usermod -aG docker "$DEFAULT_USER" || true

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
kubectl version --client=true
kind version

echo ""
echo "Bootstrap completed successfully at $(date)"
echo "Log file: $LOG_FILE"