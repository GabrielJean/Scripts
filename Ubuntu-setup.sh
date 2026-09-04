#!/bin/bash

# Run privileged commands directly when already root. For other users, use
# non-interactive sudo so the script never unexpectedly prompts for a password.
if [ "$(id -u)" -eq 0 ]; then
    run_as_root() { "$@"; }
else
    if ! command -v sudo >/dev/null 2>&1; then
        echo "This script must run as root or with passwordless sudo."
        exit 1
    fi

    if ! sudo -n -v >/dev/null 2>&1; then
        echo "This script requires root access or passwordless sudo."
        echo "Run it as root, or configure sudo to allow the required commands without a password."
        exit 1
    fi

    run_as_root() { sudo -n "$@"; }
fi

# Optional installs (default = No)
read -rp "Install Azure CLI? [y/N]: " azureInstall
azureInstall=${azureInstall:-N}

read -rp "Install kubectl? [y/N]: " kubectlInstall
kubectlInstall=${kubectlInstall:-N}

read -rp "Install Docker? [y/N]: " dockerInstall
dockerInstall=${dockerInstall:-N}

echo
echo "Updating system..."
run_as_root apt update
run_as_root apt upgrade -y

echo
echo "Installing common packages..."
run_as_root apt install -y \
    git \
    htop \
    curl \
    wget \
    zsh \
    bash-completion \
    ca-certificates \
    gnupg

if [[ $azureInstall =~ ^[Yy]$ ]]; then
    echo
    echo "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | run_as_root bash
fi

if [[ $kubectlInstall =~ ^[Yy]$ ]]; then
    echo
    echo "Installing kubectl..."

    kubernetesMinorVersion=$(curl -fsSL https://dl.k8s.io/release/stable.txt | cut -d. -f1,2)
    if [ -z "$kubernetesMinorVersion" ]; then
        echo "Unable to determine the current stable Kubernetes version."
        exit 1
    fi

    run_as_root install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/${kubernetesMinorVersion}/deb/Release.key |
        gpg --dearmor |
        run_as_root tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null

    printf 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/%s/deb/ /\n' "$kubernetesMinorVersion" |
        run_as_root tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

    run_as_root apt update
    run_as_root apt install -y kubectl
fi

if [[ $dockerInstall =~ ^[Yy]$ ]]; then
    echo
    echo "Installing Docker..."

    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    run_as_root sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh

    run_as_root apt install -y docker-compose-plugin

    run_as_root usermod -aG docker "$USER"

    echo
    echo "Added $USER to the docker group."
    echo "Log out and back in for the group change to take effect."
fi

echo
echo "Installing Prezto..."

if [ ! -d "${ZDOTDIR:-$HOME}/.zprezto" ]; then
    git clone --recursive \
        https://github.com/sorin-ionescu/prezto.git \
        "${ZDOTDIR:-$HOME}/.zprezto"
fi

zsh <<'EOF'
setopt EXTENDED_GLOB

for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
    ln -sf "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
done
EOF

# Configure Zsh
grep -qxF 'autoload -U +X bashcompinit && bashcompinit' "$HOME/.zshrc" 2>/dev/null || \
echo 'autoload -U +X bashcompinit && bashcompinit' >> "$HOME/.zshrc"

if command -v az >/dev/null 2>&1; then
    grep -qxF 'source /etc/bash_completion.d/azure-cli' "$HOME/.zshrc" 2>/dev/null || \
    echo 'source /etc/bash_completion.d/azure-cli' >> "$HOME/.zshrc"
fi

if command -v kubectl >/dev/null 2>&1; then
    grep -qxF 'source <(kubectl completion zsh)' "$HOME/.zshrc" 2>/dev/null || \
    echo 'source <(kubectl completion zsh)' >> "$HOME/.zshrc"
fi

echo
echo "Setting ZSH as default shell..."
run_as_root chsh -s "$(which zsh)" "$USER"

echo
echo "Configuring Git..."
git config --global credential.helper store

echo
echo "========================================"
echo "Setup complete!"
echo "========================================"

if [[ $dockerInstall =~ ^[Yy]$ ]]; then
    echo
    echo "Docker was installed."
    echo "Please log out and back in before using Docker."
fi

echo
echo "Restart your terminal (or log out and back in) to begin using Zsh."
