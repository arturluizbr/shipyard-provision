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

# Get Node Resource Constraints for Shipyard Engine Scheduling
DOCKERNODE_CPUS = $(ssh -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT $DOCKERNODE_USER@$DOCKERNODE_HOST -p $DOCKERNODE_PORT nproc)
DOCKERNODE_RAM = $(ssh -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT $DOCKERNODE_USER@$DOCKERNODE_HOST -p $DOCKERNODE_PORT 'echo "scale = 0; $(grep -oP "(?<=MemTotal:         )\d+?(?=\skB)" /proc/meminfo) / 1024" | bc')

ssh -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT $DOCKERNODE_USER@$DOCKERNODE_HOST -p $DOCKERNODE_PORT "bash -s" -- < scripts/new_docker_node_provision_remote.sh $DOCKERNODE_HOST

# Copy CSR from remote to local
scp -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT -P $DOCKERNODE_PORT $DOCKERNODE_USER@$DOCKERNODE_HOST:/tmp/dockerd.csr /opt/shipyard-provision/docker-csr/$DOCKERNODE_HOST.csr

# Sign CSR
openssl x509 -req -days 3650 -in /opt/shipyard-provision/docker-csr/$DOCKERNODE_HOST.csr -CA /etc/ssl/certs/cacert.pem -CAkey /etc/ssl/private/cakey.pem -out /opt/shipyard-provision/docker-certs/certs/$DOCKERNODE_HOST-cert.pem

# Copy CSR from local to remote
scp -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT -P $DOCKERNODE_PORT /opt/shipyard-provision/docker-certs/certs/$DOCKERNODE_HOST-cert.pem $DOCKERNODE_USER@$DOCKERNODE_HOST:/etc/ssl/certs/dockerd-cert.pem

# Stop Multiplexed Connection
ssh -O stop -o ControlPath=/tmp/ssh-control-$DOCKERNODE_USER@$DOCKERNODE_HOST:$DOCKERNODE_PORT $DOCKERNODE_USER@$DOCKERNODE_HOST -p $DOCKERNODE_PORT

# Add Engine to Shipyard
docker rm shipyard-cli
docker run shipyard-cli shipyard login # TODO: Check if properly logged in

# Copy Certificate Files
docker run shipyard-cli /bin/bash -c 'cat > /etc/ssl/certs/shipyard-cacert.pem' < /etc/ssl/certs/cacert.pem

# Copy Certificate Files
docker run shipyard-cli /bin/bash -c 'cat > /etc/ssl/certs/shipyard-cert.pem' < /opt/shipyard-provision/shipyard-certs/certs/shipyard-cert.pem

docker run shipyard-cli /bin/bash -c 'cat > /etc/ssl/private/shipyard-key.pem' < /opt/shipyard-provision/shipyard-certs/private/shipyard-key.pem

# Add the Engine to Shipyard
docker run shipyard-cli add-engine --addr https://$DOCKERNODE_HOST:2376 --ca-cert /etc/ssl/certs/shipyard-cacert.pem --ssl-cert /etc/ssl/certs/shipyard-cert.pem --ssl-key /etc/ssl/private/shipyard-key.pem -cpus $DOCKERNODE_CPUS --memory $DOCKERNODE_RAM
