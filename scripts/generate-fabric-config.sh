#!/bin/bash

# Exit on first error
set -e

# Clean the previous files
rm -rf fabric-config/ca
rm -rf fabric-config/msp
rm -rf fabric-config/genesis.block

# Create directories for crypto material
mkdir -p fabric-config/ca
mkdir -p fabric-config/msp/ordererOrganizations/example.com/orderers/orderer.example.com/msp
mkdir -p fabric-config/msp/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp
mkdir -p fabric-config/msp/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp

echo "Using cryptogen tool to generate crypto materials..."

# Use Docker to run cryptogen and configtxgen tools
docker run --rm -v $(pwd)/fabric-config:/etc/hyperledger/fabric hyperledger/fabric-tools:2.5 /bin/bash -c '
set -e

# Generate crypto materials for orderer organization
cryptogen generate --config=/etc/hyperledger/fabric/crypto-config-orderer.yaml --output=/etc/hyperledger/fabric/msp

# Generate crypto materials for peer organization
cryptogen generate --config=/etc/hyperledger/fabric/crypto-config-org1.yaml --output=/etc/hyperledger/fabric/msp

# Generate genesis block
configtxgen -profile OneOrgOrdererGenesis -channelID system-channel -outputBlock /etc/hyperledger/fabric/genesis.block -configPath /etc/hyperledger/fabric
'

echo "Crypto materials and genesis block generated."

# Make the script executable
chmod +x scripts/generate-fabric-config.sh

echo "Done! You can now run docker-compose up to start the Hyperledger Fabric network." 