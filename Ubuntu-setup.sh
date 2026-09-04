#!/usr/bin/env bash
# Installs common tools, Zsh, and Prezto for the invoking user.
# Run as: ./install-dev-setup.sh
# It will use sudo when required. Do not run `sudo -i` first unless you
# intentionally want to configure root's shell.

set -Eeuo pipefail

if [[ $(id -u) -eq 0 ]]; then
    # sudo preserves SUDO_USER, so `sudo ./install-dev-setup.sh` still
    # configures the person who invoked sudo rather than root.
    TARGET_USER=${SUDO_USER:-root}
    run_as_root() { "$@"; }
else
    TARGET_USER=$(id -un)
    run_as_root() { sudo "$@"; }
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | awk -F: '{print $6}')
if [[ -z $TARGET_HOME || ! -d $TARGET_HOME ]]; then
    echo "Cannot determine a valid home directory for $TARGET_USER." >&2
    exit 1
fi

# ZDOTDIR is normally unset. If it is set, respect it only when it is an
# absolute path; otherwise keep all Zsh files in the target user's home.
if [[ ${ZDOTDIR:-} == /* ]]; then
    TARGET_ZDOTDIR=$ZDOTDIR
else
    TARGET_ZDOTDIR=$TARGET_HOME
fi
PREZTO_DIR="$TARGET_ZDOTDIR/.zprezto"

run_as_target() {
    if [[ $(id -u) -eq 0 && $TARGET_USER != root ]]; then
        runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" ZDOTDIR="$TARGET_ZDOTDIR" "$@"
    else
        env HOME="$TARGET_HOME" ZDOTDIR="$TARGET_ZDOTDIR" "$@"
    fi
}

read -r -p "Install Azure CLI? [y/N]: " azureInstall
azureInstall=${azureInstall:-N}
read -r -p "Install kubectl? [y/N]: " kubectlInstall
kubectlInstall=${kubectlInstall:-N}
read -r -p "Install Docker? [y/N]: " dockerInstall
dockerInstall=${dockerInstall:-N}

echo
echo "Updating package lists..."
run_as_root env DEBIAN_FRONTEND=noninteractive apt-get update
run_as_root env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo
echo "Installing common packages, including Zsh..."
run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git htop curl wget zsh bash-completion ca-certificates gnupg

ZSH_PATH=$(command -v zsh)
if [[ -z $ZSH_PATH || ! -x $ZSH_PATH ]]; then
    echo "Zsh was not installed successfully." >&2
    exit 1
fi

if [[ $azureInstall =~ ^[Yy]$ ]]; then
    echo "Installing Azure CLI..."
    curl -fsSL https://aka.ms/InstallAzureCLIDeb | run_as_root bash
fi

if [[ $kubectlInstall =~ ^[Yy]$ ]]; then
    echo "Installing kubectl..."
    kubernetesMinorVersion=$(curl -fsSL https://dl.k8s.io/release/stable.txt | cut -d. -f1,2)
    if [[ -z $kubernetesMinorVersion ]]; then
        echo "Unable to determine the current stable Kubernetes version." >&2
        exit 1
    fi

    run_as_root install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/${kubernetesMinorVersion}/deb/Release.key" \
        | gpg --dearmor \
        | run_as_root tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null
    printf 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/%s/deb/ /\n' "$kubernetesMinorVersion" \
        | run_as_root tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get update
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y kubectl
fi

if [[ $dockerInstall =~ ^[Yy]$ ]]; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    run_as_root sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin
    run_as_root usermod -aG docker "$TARGET_USER"
fi

echo
echo "Installing Prezto for $TARGET_USER..."
run_as_target mkdir -p "$TARGET_ZDOTDIR"
if [[ ! -d $PREZTO_DIR/.git ]]; then
    if [[ -e $PREZTO_DIR ]]; then
        echo "$PREZTO_DIR exists but is not a Prezto Git checkout; refusing to overwrite it." >&2
        exit 1
    fi
    run_as_target git clone --recursive https://github.com/sorin-ionescu/prezto.git "$PREZTO_DIR"
else
    run_as_target git -C "$PREZTO_DIR" submodule update --init --recursive
fi

# Link Prezto's runcom files. Existing non-Prezto dotfiles are retained as
# timestamped backups instead of being silently overwritten.
backup_suffix=".before-prezto-$(date +%Y%m%d-%H%M%S)"
for rcfile in "$PREZTO_DIR"/runcoms/*; do
    name=$(basename "$rcfile")
    [[ $name == README.md ]] && continue
    destination="$TARGET_ZDOTDIR/.$name"

    if [[ -e $destination || -L $destination ]]; then
        if [[ $(readlink -f "$destination") == $(readlink -f "$rcfile") ]]; then
            continue
        fi
        run_as_target mv "$destination" "${destination}${backup_suffix}"
        echo "Backed up $destination to ${destination}${backup_suffix}"
    fi
    run_as_target ln -s "$rcfile" "$destination"
done

# Prezto's default completion module handles Zsh completions. In particular,
# don't append to ~/.zshrc here: it is a symlink into the Prezto repository.
# Put personal additions in ~/.zpreztorc or manage a separate local file.

echo "Setting Zsh as the default shell for $TARGET_USER..."
run_as_root chsh -s "$ZSH_PATH" "$TARGET_USER"

run_as_target git config --global credential.helper store

echo
echo "========================================"
echo "Setup complete for $TARGET_USER"
echo "========================================"
if [[ $dockerInstall =~ ^[Yy]$ ]]; then
    echo "Log out and back in before using Docker."
fi
echo "Open a new terminal (or log out and back in) to start Zsh with Prezto."
