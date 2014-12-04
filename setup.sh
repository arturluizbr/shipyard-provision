#!/bin/bash

echo Shipyard Cluster Provisioning Script
echo ------------------------------------
echo
echo

if [[ $EUID -ne 0 ]]; then
	echo "You must run this script as root or sudo!" 2>&1
	echo "Try: sudo ./setup.sh" 2>&1
	exit 1
fi

# Configure This System

# System Update and Upgrade
apt-get update
apt-get upgrade

apt-get install curl wget openssl

# Change UFW Rules
ufw default deny incoming

ufw logging medium

ufw allow ssh

ufw enable

# Configure Certificate Authority
echo "Configuring the Certificate Authority"
echo "Please enter the reachable IP address for the will-be Certificate Authority node: "
read CERTIFICATE_AUTHORITY_IP_ADDRESS

echo "Please enter the port for the node [22]: "
read -i 22 -e CERTIFICATE_AUTHORITY_PORT

echo "Please enter the user to use to connect to the node [root]: "
read -i root -e CERTIFICATE_AUTHORITY_USER

echo "Launching Certificate Authority Provision Script. The script will be run on the node itself."
echo "Launching SSH..."
ssh $CERTIFICATE_AUTHORITY_USER@$CERTIFICATE_AUTHORITY_IP_ADDRESS -p $CERTIFICATE_AUTHORITY_PORT 'bash -s' < scripts/certauthority_provision_remote.sh

# Configure Shipyard Controller
echo "Configuring the Shipyard Controller"
echo "Please enter the reachable IP address for the will-be Shipyard Controller node: "
read SHIPYARD_CONTROLLER_IP_ADDRESS

echo "Please enter the port for the node [22]: "
read -i 22 -e SHIPYARD_CONTROLLER_PORT

echo "Please enter the user to use to connect to the node [root]: "
read -i root -e SHIPYARD_CONTROLLER_USER

echo "Launching Shipyard Controller Provision Script. The script will be run on the node itself."
echo "Launching SSH..."
ssh $SHIPYARD_CONTROLLER_USER@$SHIPYARD_CONTROLLER_IP_ADDRESS -p $SHIPYARD_CONTROLLER_PORT 'bash -s' < scripts/shipyard_provision_remote.sh

# Install Docker and Shipyard CLI
curl -sSL https://get.docker.com/ubuntu/ | sh

docker pull shipyard/shipyard-cli

# Create Shipyard CLI Container
docker create --interactive --tty --name shipyard-cli shipyard/shipyard-cli

# Log into Shipyard CLI for this script to perform further operations
echo "Now you will be asked to login to the Shipyard Controller"
echo "This is for the script to perform initialisation. After the process, the container and credential will be removed."
docker run shipyard-cli shipyard login

# TODO: Perform some actions here, like adding a new Engine.

# Delete Shipyard CLI Container
docker rm shipyard-cli