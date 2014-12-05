#!/bin/bash

echo Shipyard Cluster Add Engine Script
echo ------------------------------------
echo
echo

if [[ $EUID -ne 0 ]]; then
	echo "You must run this script as root or sudo!"
	echo "Elevating Privilege..."
	sudo "$0" "$@"
    exit $?
fi

# Configure Shipyard Controller
echo "Configuring the Shipyard Controller"
echo "Please enter the reachable IP address for the will-be Shipyard Controller node: "
read DOCKERNODE_HOST

echo "Please enter the port for the node [22]: "
read -i 22 -e DOCKERNODE_PORT

echo "Please enter the user to use to connect to the node [root]: "
read -i root -e DOCKERNODE_USER

echo "Launching Shipyard Controller Provision Script. The script will be run on the node itself."
echo "Launching SSH..."

# Start Multiplexed Connection - Timeout: Indefinite
ssh -o ControlMaster=auto -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT -o ControlPersist=yes $DOCKERNODE_USER@$DOCKERNODE_HOST -p $DOCKERNODE_PORT

# Run Provision Script
ssh -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT $DOCKERNODE_USER@$DOCKERNODE_HOST -p $DOCKERNODE_PORT "bash -s" -- < scripts/new_docker_node_provision_remote.sh $DOCKERNODE_HOST

scp -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT -P $DOCKERNODE_PORT $DOCKERNODE_USER@$DOCKERNODE_HOST:/opt/dockerd.csr /opt/shipyard-provision/docker-csr/$DOCKERNODE_HOST.csr

openssl x509 -req -days 3650 -in /opt/shipyard-provision/docker-csr/$DOCKERNODE_HOST.csr -CA /etc/ssl/certs/cacert.pem -CAkey /etc/ssl/private/cakey.pem -out /opt/shipyard-provision/docker-certs/$DOCKERNODE_HOST-cert.pem

scp -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT -P $DOCKERNODE_PORT /opt/shipyard-provision/docker-certs/$DOCKERNODE_HOST-cert.pem $DOCKERNODE_USER@$DOCKERNODE_HOST:/etc/ssl/certs/dockerd-cert.pem

# Stop Multiplexed Connection
ssh -O stop -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT $DOCKERNODE_USER@$DOCKERNODE_HOST -p $DOCKERNODE_PORT
