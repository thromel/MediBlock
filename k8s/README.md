# MediBlock Kubernetes Deployment

This directory contains the Kubernetes manifests and deployment scripts for the MediBlock platform.

## Prerequisites

- Kubernetes cluster (Docker Desktop for local development)
- kubectl configured to connect to your cluster
- Hyperledger Fabric tools

## Deployment

For a simplified deployment experience, use the provided deployment script:

```bash
./scripts/deploy-mediblock.sh
```

This script performs the following tasks:
- Creates the necessary namespace
- Cleans up existing deployments if they exist
- Generates certificates with proper key usage settings
- Creates configuration files for orderer and peer nodes
- Generates the genesis block
- Deploys orderer and peer with proper volume mounts
- Deploys supporting services (IPFS, Go service, Python service, frontend)

## Manual Deployment

For manual deployment, follow these steps as documented in the `DEPLOYMENT.md` file:

1. Create namespace and base ConfigMaps
2. Generate certificates using `./scripts/apply-fabric-ca-certs.sh`
3. Create configuration files and ConfigMaps
4. Generate genesis block using `./scripts/generate-genesis.sh`
5. Create and apply orderer and peer deployments
6. Deploy supporting services

## Manifest Structure

- `00-namespace.yaml`: Creates the MediBlock namespace
- `01-configmap.yaml`: General application configuration
- `02-fabric.yaml`: Hyperledger Fabric components (deprecated - use deployment script)
- `03-ipfs.yaml`: IPFS deployment
- `04-go-service.yaml`: Go service deployment
- `05-python-service.yaml`: Python service deployment
- `06-nextjs-frontend.yaml`: Frontend deployment

## Troubleshooting

If you encounter issues with the deployment, check:

1. Certificate key usage settings
2. Genesis block mounting
3. BCCSP configuration
4. Volume mounts and folder structure

For detailed logs:
```bash
kubectl logs -n mediblock <pod-name>
```

## Cleanup

To clean up all resources:
```bash
kubectl delete namespace mediblock
```

## Directory Structure

- `manifests/`: Contains all Kubernetes resource definitions
  - `00-namespace.yaml`: Creates the mediblock namespace
  - `01-configmap.yaml`: ConfigMap with environment variables
  - `02-fabric.yaml`: Hyperledger Fabric components (orderer, peer, CA)
  - `03-ipfs.yaml`: IPFS node for storing encrypted medical records
  - `04-go-service.yaml`: Go microservice for blockchain interactions
  - `05-python-service.yaml`: Python service for encryption and IPFS handling
  - `06-nextjs-frontend.yaml`: NextJS frontend application

## Development Setup

For local development, we provide a script that sets up everything you need:

```bash
# Make sure the scripts are executable
chmod +x scripts/setup-k8s-dev.sh
chmod +x scripts/cleanup-k8s-dev.sh

# Setup development environment
./scripts/setup-k8s-dev.sh
```

This script:
1. Starts Minikube (if not running)
2. Builds all container images
3. Deploys all components to Kubernetes
4. Sets up port forwarding for the frontend
5. Shows how to access the application

## Cleanup

To clean up the development environment:

```bash
./scripts/cleanup-k8s-dev.sh
```

## Production Deployment

For production deployment, you'll need to:

1. Build and push container images to a registry
2. Update image references in the YAML files
3. Set up persistent volumes for data
4. Configure proper secrets management
5. Deploy to your production Kubernetes cluster

## Architecture

```
+-----------------+     +------------------+     +------------------+
|                 |     |                  |     |                  |
| NextJS Frontend | --> | Python Service   | --> | Go Service       |
|                 |     |                  |     |                  |
+-----------------+     +------------------+     +------------------+
                              |                         |
                              v                         v
                        +------------+           +--------------+
                        |            |           |              |
                        | IPFS Node  |           | Fabric Peer  |
                        |            |           |              |
                        +------------+           +--------------+
                                                        |
                                                        v
                                                  +------------+
                                                  |            |
                                                  |  Orderer   |
                                                  |            |
                                                  +------------+
```

## Troubleshooting

### Common Issues

1. **Pods stuck in Pending state**: Check if your cluster has enough resources with `kubectl describe pods`.
2. **Services not accessible**: Ensure the minikube tunnel is running.
3. **Container image issues**: If you update code, rebuild images with `docker build`.

### Logs

To view logs from a specific component:

```bash
kubectl logs -n mediblock deployment/nextjs-frontend
kubectl logs -n mediblock deployment/python-service
kubectl logs -n mediblock deployment/go-service
```

### Accessing Components Directly

```bash
# Port forward to access the frontend directly
kubectl port-forward -n mediblock service/nextjs-frontend 3000:3000

# Port forward to access the Python API directly
kubectl port-forward -n mediblock service/python-service 5000:5000

# Access IPFS UI
kubectl port-forward -n mediblock service/ipfs 5001:5001
# Then open http://localhost:5001/webui in your browser
``` 