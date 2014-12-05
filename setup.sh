#!/bin/bash

echo Shipyard Cluster Provisioning Script
echo ------------------------------------
echo
echo

if [[ $EUID -ne 0 ]]; then
	echo "You must run this script as root or sudo!"
	echo "Elevating Privilege..."
	sudo "$0" "$@"
    exit $?
fi

# Configure This System

# System Update and Upgrade
apt-get update
apt-get upgrade

apt-get install curl wget openssl

# Change UFW Rules
ufw default deny incoming
ufw default allow routed # Docker

ufw logging medium

ufw allow ssh
ufw allow

ufw enable

###########################
# Configure Certificate Authority

scripts/certauthority_provision.sh

###########################
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

# Start Multiplexed Connection - Timeout: Indefinite
ssh -o ControlMaster=auto -o ControlPath=/tmp/ssh-control-$SHIPYARD_CONTROLLER_USER@$SHIPYARD_CONTROLLER_IP_ADDRESS:$SHIPYARD_CONTROLLER_PORT -o ControlPersist=yes $SHIPYARD_CONTROLLER_USER@$SHIPYARD_CONTROLLER_IP_ADDRESS -p $SHIPYARD_CONTROLLER_PORT

# Run Provision Script
ssh -o ControlPath=/tmp/ssh-control-$SHIPYARD_CONTROLLER_USER@$SHIPYARD_CONTROLLER_IP_ADDRESS:$SHIPYARD_CONTROLLER_PORT $SHIPYARD_CONTROLLER_USER@$SHIPYARD_CONTROLLER_IP_ADDRESS -p $SHIPYARD_CONTROLLER_PORT 'bash -s' < scripts/shipyard_provision_remote.sh

###############################
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

## Stop Persistent SSH Connections

# Stop Multiplexed Connection - Shipyard Controller
ssh -O stop -o ControlPath=/tmp/ssh-control-$SHIPYARD_CONTROLLER_USER@$SHIPYARD_CONTROLLER_IP_ADDRESS:$SHIPYARD_CONTROLLER_PORT $SHIPYARD_CONTROLLER_USER@$SHIPYARD_CONTROLLER_IP_ADDRESS -p $SHIPYARD_CONTROLLER_PORT
