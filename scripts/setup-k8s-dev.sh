#!/bin/bash

# Exit on any error
set -e

echo "🔧 Setting up MediBlock Kubernetes development environment..."

# Check for required tools
for cmd in docker kubectl minikube; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ $cmd is required but not installed. Please install it first."
        exit 1
    fi
done

# Start minikube if not running
if ! minikube status | grep -q "Running"; then
    echo "🚀 Starting minikube..."
    minikube start --memory=4096 --cpus=2
fi

# Enable ingress addon
echo "🔌 Enabling ingress addon..."
minikube addons enable ingress

# Set docker environment to use minikube's docker daemon
echo "🐳 Configuring docker to use minikube daemon..."
eval $(minikube docker-env)

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
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/ca-org1
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/orderer
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/peer0-org1
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/go-service
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/python-service
kubectl wait --namespace mediblock --for=condition=available --timeout=300s deployment/nextjs-frontend

# Setup minikube tunnel for accessing services
echo "🔗 Setting up minikube tunnel in background..."
minikube tunnel > /dev/null 2>&1 &
TUNNEL_PID=$!

# Get NextJS frontend URL
FRONTEND_PORT=$(kubectl get service nextjs-frontend -n mediblock -o jsonpath='{.spec.ports[0].nodePort}')
FRONTEND_URL="http://$(minikube ip):$FRONTEND_PORT"

echo "✅ MediBlock deployment complete!"
echo "🌐 Access the application at: $FRONTEND_URL"
echo "⚙️ Kubernetes dashboard: $(minikube dashboard --url)"
echo ""
echo "💻 To view logs:"
echo "   kubectl logs -n mediblock deployment/nextjs-frontend"
echo "   kubectl logs -n mediblock deployment/python-service"
echo "   kubectl logs -n mediblock deployment/go-service"
echo ""
echo "🛑 To clean up resources:"
echo "   kubectl delete namespace mediblock"
echo "   kill $TUNNEL_PID  # To stop minikube tunnel"

# Make the script stop the tunnel if interrupted
trap "kill $TUNNEL_PID" EXIT

# Keep script running to maintain tunnel
echo "Press Ctrl+C to exit and cleanup..."
while true; do sleep 1; done 