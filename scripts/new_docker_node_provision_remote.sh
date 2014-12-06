#!/bin/bash

echo Shipyard Cluster Provisioning Script
echo ------------------------------------
echo
echo

DOCKER_DAEMON_HOSTNAME = $1
DOCKER_DAEMON_PUBLIC_IP = $2

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
ufw allow 2375/tcp # TODO: Restrict it with originating IP

ufw enable

# Install Docker
curl -sSL https://get.docker.com/ubuntu/ | sh
service docker stop

# Change Docker Settings
sed -i "s/#DOCKER_OPTS=\"--dns 8.8.8.8 --dns 8.8.4.4 \"/DOCKER_OPTS=\"--dns 8.8.8.8 --dns 8.8.4.4 -H tcp://$DOCKER_DAEMON_PUBLIC_IP:2375 --tlsverify --tlscacert=/etc/ssl/certs/dockercluster-ca.pem --tlscert=/etc/ssl/certs/dockerd-cert.pem --tlskey=/etc/ssl/private/dockerd-key.pem\"/" /etc/default/docker

# Generate Private Docker Certificate
openssl genrsa -nodes -out /etc/ssl/private/dockerd-key.pem 4096

openssl req -subj "/CN=$DOCKER_DAEMON_HOSTNAME" -new -key /etc/ssl/private/dockerd-key.pem -out /tmp/dockerd.csr
