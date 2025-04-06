# MediBlock Deployment Guide

This document provides comprehensive instructions for deploying the MediBlock platform using the simplified deployment script.

## Overview

MediBlock is a healthcare blockchain platform built using Hyperledger Fabric. The platform consists of several components:

1. **Hyperledger Fabric Network** - A blockchain network with orderer and peer nodes
2. **Go Service** - A bridging service connecting the blockchain to other microservices
3. **Python Service** - Handles advanced cryptography and API operations
4. **NextJS Frontend** - User interface for interacting with the platform
5. **IPFS** - For storing larger data objects with references on the blockchain

## Prerequisites

Before deploying MediBlock, ensure you have the following prerequisites installed:

- **Docker** (20.10.x or newer)
- **Kubernetes** (1.19+ - Docker Desktop or Minikube for local development)
- **kubectl** (1.19+ - matching your Kubernetes version)
- **OpenSSL** (1.1.1 or newer)

## Simplified Deployment

We've created a single comprehensive script to handle the entire deployment process.

### One-Command Deployment

To deploy the entire MediBlock platform with a single command:

```bash
# Make the script executable
chmod +x scripts/deploy-mediblock.sh

# Run the deployment script
./scripts/deploy-mediblock.sh
```

This script will:

1. Check for required prerequisites
2. Build all necessary Docker images
3. Set up the Kubernetes namespace
4. Generate Fabric certificates using Fabric CA
5. Deploy Hyperledger Fabric components (CA, orderer, peer)
6. Create and configure a Fabric channel
7. Deploy application services (Go, Python, NextJS frontend)
8. Display access information when complete

### Deployment Options

The deployment script supports different environments:

```bash
# Deploy to local Docker Desktop Kubernetes
./scripts/deploy-mediblock.sh local  # 'local' is the default if not specified

# For future environment support
# ./scripts/deploy-mediblock.sh [environment]
```

## Deployment Process Explained

The deployment process follows these steps:

### 1. Certificate Generation

The script deploys a Fabric CA job in Kubernetes that:
- Creates a Fabric CA server
- Generates certificates for the orderer and peer nodes
- Stores the certificates in Kubernetes ConfigMaps and Secrets

### 2. Fabric Network Deployment

After certificates are generated, the script:
- Deploys the Fabric orderer node
- Deploys the Fabric peer node
- Configures the nodes with the generated certificates

### 3. Channel Creation

Once the Fabric components are running:
- A channel creation job is executed
- The peer is joined to the channel
- Anchor peers are configured

### 4. Application Services

Finally, the script deploys:
- IPFS for off-chain storage
- Go service for blockchain interaction
- Python service for advanced cryptography
- NextJS frontend for user interaction

## Accessing the Application

After deployment completes, you can access:

- The frontend at the displayed URL (typically http://localhost:[NodePort])
- Individual service logs using the kubectl commands provided in the output

## Troubleshooting

If you encounter issues during deployment:

1. **Certificate Generation Fails**
   - Check the Fabric CA job logs: `kubectl logs -n mediblock job/fabric-ca-cert-generation`
   - Ensure Kubernetes has sufficient permissions to create the required resources

2. **Fabric Components Don't Start**
   - Check component logs: `kubectl logs -n mediblock deployment/orderer`
   - Verify certificate paths and configuration in the deployed pods
   - For orderer "CrashLoopBackOff" issues, ensure the genesis block is properly mounted and the folders are created with proper permissions
   - If the orderer continues to fail, check if all required volumes are mounted correctly in the manifest

3. **Orderer Specific Issues**
   - If the orderer is in "CrashLoopBackOff" state, check logs: `kubectl logs -n mediblock deployment/orderer`
   - Common issues include missing genesis block, incorrect volume mounts, or permission problems
   - Ensure the initContainer properly sets up all required folders and file permissions
   - Verify that the genesis block is correctly mounted to `/var/hyperledger/fabric/config/genesisblock`
   - Make sure all required certificates are properly copied to the MSP directory structure

4. **Channel Creation Fails**
   - Examine the channel creator job logs
   - Ensure orderer and peer are fully running before channel creation
   - Verify that the system channel is properly bootstrapped in the orderer logs

5. **Application Services Issues**
   - Check individual service logs
   - Verify they can connect to the Fabric network

## Resetting the Deployment

If you need to completely reset the deployment due to persistent issues:

```bash
# Delete the namespace
kubectl delete namespace mediblock

# Wait for deletion to complete
kubectl wait --for=delete namespace/mediblock --timeout=300s

# Redeploy
./scripts/deploy-mediblock.sh
```

## Clean Up

To remove all deployed resources:

```bash
kubectl delete namespace mediblock
```

## Manual Deployment (Alternative)

If you need more control over the deployment process, you can run each step individually:

1. Set up namespace: `kubectl apply -f k8s/manifests/00-namespace.yaml`
2. Create ConfigMap: `kubectl apply -f k8s/manifests/01-configmap.yaml`
3. Generate certificates: `kubectl apply -f k8s/manifests/01c-fabric-ca-job.yaml`
4. Deploy Fabric: `kubectl apply -f k8s/manifests/components/services.yaml`
5. Deploy orderer: `kubectl apply -f k8s/manifests/components/orderer.yaml`
6. Deploy peer: `kubectl apply -f k8s/manifests/components/peer.yaml`
7. Deploy services: `kubectl apply -f k8s/manifests/[03-06]*.yaml`

## Next Steps

After deployment, you should:

1. Deploy and instantiate chaincode for your specific use case
2. Configure the application services to interact with the chaincode
3. Set up proper authentication and authorization for production use 