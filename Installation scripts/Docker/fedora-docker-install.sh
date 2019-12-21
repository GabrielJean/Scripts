#!/bin/bash
# This script is meant to be used to provision docker on a new ubuntu server.
# Written by Gabriel Jean - 2019-08-27

# Check if user is root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi


# Install updates and basic tools
echo fastestmirror=1 >> /etc/dnf/dnf.conf
dnf update -y 
dnf install -y git htop wget curl

# Set up the docker repository
dnf -y install dnf-plugins-core

sudo dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo

# Install docker 
dnf install -y docker-ce docker-ce-cli containerd.io


## Install Docker-Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose


# Start and Enable Docker 
systemctl start docker && systemctl enable docker


# Reboot server
echo "Do you want to restart the server ? [y/n]"
read reboot
if [ $reboot = "y" ]; then
    reboot
fi

echo "Server properly Installed with Docker"
