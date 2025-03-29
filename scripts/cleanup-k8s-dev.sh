#!/bin/bash

# Exit on any error
set -e

echo "🧹 Cleaning up MediBlock Kubernetes development environment..."

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is required but not installed. Please install it first."
    exit 1
fi

# Check if namespace exists
if kubectl get namespace mediblock &> /dev/null; then
    echo "🗑️ Deleting mediblock namespace and all resources within it..."
    kubectl delete namespace mediblock
else
    echo "ℹ️ No mediblock namespace found. Nothing to delete."
fi

# Check if minikube is running
if command -v minikube &> /dev/null; then
    if minikube status | grep -q "Running"; then
        read -p "❓ Do you want to stop minikube? (y/n): " stop_minikube
        if [[ $stop_minikube == "y" || $stop_minikube == "Y" ]]; then
            echo "🛑 Stopping minikube..."
            minikube stop
        fi
    fi
fi

echo "✅ Cleanup complete!" 