#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
    echo "Please do not run as root"
    exit 1
fi

# Request sudo upfront
sudo -v || exit 1

# Optional installs (default = No)
read -rp "Install Azure CLI? [y/N]: " azureInstall
azureInstall=${azureInstall:-N}

read -rp "Install kubectl? [y/N]: " kubectlInstall
kubectlInstall=${kubectlInstall:-N}

read -rp "Install Docker? [y/N]: " dockerInstall
dockerInstall=${dockerInstall:-N}

echo
echo "Updating system..."
sudo pacman -Syu --noconfirm

echo
echo "Installing common packages..."
sudo pacman -S --needed --noconfirm \
    git \
    htop \
    curl \
    wget \
    zsh \
    bash-completion

if [[ $azureInstall =~ ^[Yy]$ ]]; then
    echo
    echo "Installing Azure CLI..."
    sudo pacman -S --needed --noconfirm azure-cli
fi

if [[ $kubectlInstall =~ ^[Yy]$ ]]; then
    echo
    echo "Installing kubectl..."
    sudo pacman -S --needed --noconfirm kubectl
fi

if [[ $dockerInstall =~ ^[Yy]$ ]]; then
    echo
    echo "Installing Docker..."
    sudo pacman -S --needed --noconfirm \
        docker \
        docker-compose

    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"

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

# Configure Zsh completions
grep -qxF 'autoload -U +X bashcompinit && bashcompinit' "$HOME/.zshrc" 2>/dev/null || \
echo 'autoload -U +X bashcompinit && bashcompinit' >> "$HOME/.zshrc"

if [[ $azureInstall =~ ^[Yy]$ ]]; then
    grep -qxF 'source /usr/share/bash-completion/completions/az' "$HOME/.zshrc" 2>/dev/null || \
    echo 'source /usr/share/bash-completion/completions/az' >> "$HOME/.zshrc"
fi

if [[ $kubectlInstall =~ ^[Yy]$ ]]; then
    grep -qxF 'source <(kubectl completion zsh)' "$HOME/.zshrc" 2>/dev/null || \
    echo 'source <(kubectl completion zsh)' >> "$HOME/.zshrc"
fi

echo
echo "Setting ZSH as default shell..."
sudo chsh -s /bin/zsh "$USER"

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
```
