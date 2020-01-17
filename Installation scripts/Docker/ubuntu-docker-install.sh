#!/bin/bash
# This script is meant to be used to provision docker on a new ubuntu server.
# Written by Gabriel Jean - 2019-08-27

# Check if user is root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Install updates and basic tools
apt update
apt upgrade -y
apt install -y git htop wget curl


# Install docker dependencies 
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Download Docker repo KEY
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -


# Add Docker repository
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Install docker
apt-get -y install docker-ce

## Install Docker-Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose


# Start and Enable Docker 
systemctl start docker && systemctl enable docker

# Reboot server
#echo "Do you want to restart the server ? [y/n]"
# read reboot
# if [ $reboot = "y" ]; then
#     reboot
# fi

echo "Server properly Installed with Docker, if updates were applied you should probably reboot"
