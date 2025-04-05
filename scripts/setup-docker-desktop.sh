#!/bin/bash

# Exit on any error
set -e

echo "🔧 Setting up MediBlock Kubernetes development environment on Docker Desktop..."

# Check for required tools
for cmd in docker kubectl; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ $cmd is required but not installed. Please install it first."
        exit 1
    fi
done

# Make sure we're using Docker Desktop context
kubectl config use-context docker-desktop

# Build container images
echo "🏗️ Building container images..."

echo "Building Go service image..."
docker build -t mediblock/go-service:latest -f go-service/Dockerfile go-service

echo "Building Python service image..."
docker build -t mediblock/python-service:latest -f python-service/Dockerfile python-service

echo "Building NextJS frontend image..."
docker build -t mediblock/nextjs-frontend:latest -f nextjs-frontend/Dockerfile nextjs-frontend

# Apply Kubernetes manifests
echo "📦 Deploying to Kubernetes..."

# Create namespace and base configs
kubectl apply -f k8s/manifests/00-namespace.yaml
kubectl apply -f k8s/manifests/01-configmap.yaml
kubectl apply -f k8s/manifests/01a-fabric-secrets.yaml
kubectl apply -f k8s/manifests/01b-crypto-config.yaml
kubectl apply -f k8s/manifests/01c-cert-job.yaml

# Deploy Fabric components
echo "🧩 Deploying Hyperledger Fabric components..."
kubectl apply -f k8s/manifests/02-fabric.yaml

# Deploy IPFS
echo "🗃️ Deploying IPFS..."
kubectl apply -f k8s/manifests/03-ipfs.yaml

# Deploy services
echo "🚢 Deploying application services..."
kubectl apply -f k8s/manifests/04-go-service.yaml
kubectl apply -f k8s/manifests/05-python-service.yaml
kubectl apply -f k8s/manifests/06-nextjs-frontend.yaml

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/ca-org1 || echo "Timed out waiting for ca-org1"
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/orderer || echo "Timed out waiting for orderer"
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/peer0-org1 || echo "Timed out waiting for peer0-org1"
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/go-service || echo "Timed out waiting for go-service"
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/python-service || echo "Timed out waiting for python-service"
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/nextjs-frontend || echo "Timed out waiting for nextjs-frontend"

# Get service URLs
FRONTEND_PORT=$(kubectl get service nextjs-frontend -n mediblock -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "Not available yet")
if [[ -n "$FRONTEND_PORT" && "$FRONTEND_PORT" != "Not available yet" ]]; then
    FRONTEND_URL="http://localhost:$FRONTEND_PORT"
    echo "🌐 Access the application at: $FRONTEND_URL"
else
    echo "⚠️ Frontend service not available with NodePort yet. Check status with:"
    echo "   kubectl get services -n mediblock"
fi

echo "✅ MediBlock deployment complete!"
echo ""
echo "💻 To view logs:"
echo "   kubectl logs -n mediblock deployment/nextjs-frontend"
echo "   kubectl logs -n mediblock deployment/python-service"
echo "   kubectl logs -n mediblock deployment/go-service"
echo ""
echo "🛑 To clean up resources:"
echo "   kubectl delete namespace mediblock" 