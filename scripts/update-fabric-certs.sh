#!/bin/bash

# Exit on first error
set -e

# Check if kubectl is available
if ! command -v kubectl &> /dev/null
then
    echo "kubectl is not installed or not in the PATH. Please install it first."
    exit 1
fi

# Check current context
CURRENT_CONTEXT=$(kubectl config current-context)
echo "Using Kubernetes context: $CURRENT_CONTEXT"
echo "This script will update the Fabric certificates and related Kubernetes resources."
echo "Are you sure you want to continue? (y/n)"
read -r answer

if [[ $answer != "y" ]]; then
  echo "Operation cancelled."
  exit 0
fi

# Generate certificates locally
echo "Generating certificates locally..."
TMP_DIR=$(mktemp -d)
./scripts/generate-fabric-certs.sh -o "$TMP_DIR"

# Apply the updated resources to Kubernetes
echo "Applying updated resources to Kubernetes..."
kubectl apply -f k8s/manifests/01a-fabric-secrets.yaml
kubectl apply -f k8s/manifests/01b-crypto-config.yaml

# Restart the Fabric pods to pick up the new certificates
echo "Restarting Fabric pods..."
kubectl rollout restart deployment/orderer -n mediblock
kubectl rollout restart deployment/peer0-org1 -n mediblock

# Clean up temporary directory
rm -rf "$TMP_DIR"

echo "Fabric certificates have been updated successfully."
echo "You can check the status of the pods with: kubectl get pods -n mediblock" 