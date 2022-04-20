if [ "$(id -u)" -eq 0 ]
  then echo "Please do not run as root"
  exit
fi

sudo echo ""

if [[ $? -eq 1 ]]
then
	exit
fi

read -p "Do you want Docker? [y/n]: " -n 1 -r dockerInstall

echo "Install updates"
sudo apt update && sudo apt upgrade -y

echo "Install packages"
sudo apt install git htop curl wget

echo "Installing Azure CLI"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Installing Kubectl"
sudo az aks install-cli

if [[ $dockerInstall =~ ^[Yy]$ ]]
then
	echo "Installing Docker"
	curl -fsSL https://get.docker.com -o get-docker.sh
	sudo sh get-docker.sh
	
	echo "Install Docker-Compose"
	sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose

fi

echo "Install ZSH"
sudo apt install -y zsh

echo "Install prezto"
zsh -c 'git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"'

zsh -c 'setopt EXTENDED_GLOB
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
          ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
  done'

echo "autoload -U +X bashcompinit && bashcompinit
source /etc/bash_completion.d/azure-cli
source <(kubectl completion zsh)" >> .zshrc

sudo chsh -s /bin/zsh gabriel
