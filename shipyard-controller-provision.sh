#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "You must run this script as root or sudo!" 2>&1
	exit 1
fi

# System Update and Upgrade
apt-get update
apt-get upgrade

apt-get install curl wget vim

# Change UFW Rules
ufw default allow routed # This is requred for Docker internal routing
ufw default deny incoming

ufw logging medium

ufw allow ssh
#ufw allow 2375/tcp # Docker # Actually, this is not required on the controller host.
ufw allow 8080/tcp # Shipyard HTTP

ufw enable

# Install Docker
curl -sSL https://get.docker.com/ubuntu/ | sh

# Make Shipyard Directory
mkdir -p /var/lib/shipyard/rethinkdb/data

# Pull Docker Images
docker pull shipyard/rethinkdb
docker pull shipyard/shipyard

# Create Shipyard Service Containers
## RethinkDB
docker create --interactive --tty --name shipyard-rethinkdb --volume /var/lib/shipyard/rethinkdb/data:/data shipyard/rethinkdb
## Shipyard
docker create --interactive --tty --publish 8080:8080 --name shipyard --link shipyard-rethinkdb:rethinkdb shipyard/shipyard

# Install Upstart Service Scripts
cat << EOF > /etc/init/shipyard-rethinkdb.conf
#Upstart Script for Shipyard RethinkDB Container Service

description "Shipyard RethinkDB Container Service"
author "Michael Yoo <michael@yoo.id.au>"

start on filesystem and started docker
stop on runlevel [!2345]
respawn

script
/usr/bin/docker start -a shipyard-rethinkdb
end script
EOF

cat << EOF > /etc/init/shipyard.conf
#Upstart Script for Shipyard Container Service

description "Shipyard Container Service"
author "Michael Yoo <michael@yoo.id.au>"

start on started shipyard-rethinkdb
stop on stopping shipyard-rethinkdb
respawn

script
/usr/bin/docker start -a shipyard
end script
EOF

echo Provisioning Complete!
echo Please reboot the server to start the service.