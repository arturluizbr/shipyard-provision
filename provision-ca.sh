#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "You must run this script as root or sudo!" 2>&1
	exit 1
fi

# System Update and Upgrade
apt-get update
apt-get upgrade

apt-get install curl wget vim openssl

# Change UFW Rules
ufw default deny incoming

ufw logging medium

ufw allow ssh

ufw enable

# Create CA Directories
mkdir /etc/ssl/CA
mkdir /etc/ssl/newcerts

# Create CA Serial and Index to keep track of certs generated
echo 01 > /etc/ssl/CA/serial
touch /etc/ssl/CA/index.txt

# Change OpenSSL Configuration
sed -i 's/dir\s*=\s.\/demoCA/dir = \/etc\/ssl/' /etc/ssl/openssl.cnf
sed -i 's/database\s*=\s$dir\/index.txt/database = $dir\/CA\/index.txt/' /etc/ssl/openssl.cnf
sed -i 's/certificate\s*=\s$dir\/cacert.pem/certificate = $dir\/certs\/cacert.pem/' /etc/ssl/openssl.cnf
sed -i 's/serial\s*=\s$dir\/serial/serial = $dir\/CA\/serial/' /etc/ssl/openssl.cnf

sed -i 's/# keyUsage = nonRepudiation, digitalSignature, keyEncipherment/keyUsage = nonRepudiation, digitalSignature, keyEncipherment/' /etc/ssl/openssl.cnf
sed -i 's/# keyUsage = cRLSign, keyCertSign/keyUsage = cRLSign, keyCertSign/' /etc/ssl/openssl.cnf

# Create Self-Signed Root Certificate
## Create Private Key for CA
openssl genrsa -aes256 -out /etc/ssl/private/cakey.pem 4096
chmod 400 /etc/ssl/private/cakey.pem

## Create the CA Certificate
openssl req -new -x509 -days 3650 -key /etc/ssl/private/cakey.pem -sha256 -extensions v3_ca -out /etc/ssl/certs/cacert.pem
chmod 444 /etc/ssl/certs/cacert.pem

# Install Helper Scripts
## TODO: To be completed in the future

# Provisioning Complete
echo Provisioning Complete! CA certificates have been generated.