#!/bin/bash

#####################################################
# MediBlock Deployment Script                        
# This script automates the complete deployment of   
# the MediBlock platform on Kubernetes               
#####################################################

set -e # Exit on any error

# Text formatting
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

NAMESPACE="mediblock"
TARGET_ENV="${1:-local}" # Default to local if not specified

# Function to print section headers
print_section() {
  echo -e "\n${BOLD}${BLUE}➡️  $1${NC}\n"
}

# Function to print success messages
print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

# Function to print error messages and exit
print_error() {
  echo -e "${RED}❌ $1${NC}"
  exit 1
}

# Function to print info messages
print_info() {
  echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
  print_section "Checking prerequisites"
  
  local MISSING_TOOLS=0
  
  for cmd in kubectl docker openssl; do
    if ! command -v $cmd &> /dev/null; then
      print_error "$cmd is required but not installed. Please install it first."
      MISSING_TOOLS=1
    else
      print_success "$cmd is installed"
    fi
  done
  
  if [ $MISSING_TOOLS -eq 1 ]; then
    exit 1
  fi
  
  # Check if running in the right context
  if [ "$TARGET_ENV" == "local" ]; then
    kubectl config use-context docker-desktop || print_error "Failed to switch to docker-desktop context"
    print_success "Using docker-desktop Kubernetes context"
  fi
}

# Function to build container images
build_images() {
  print_section "Building container images"
  
  print_info "Building Go service image..."
  docker build -t mediblock/go-service:latest -f go-service/Dockerfile go-service
  
  print_info "Building Python service image..."
  docker build -t mediblock/python-service:latest -f python-service/Dockerfile python-service
  
  print_info "Building NextJS frontend image..."
  docker build -t mediblock/nextjs-frontend:latest -f nextjs-frontend/Dockerfile nextjs-frontend
  
  print_success "All container images built successfully"
}

# Function to create and setup namespace
setup_namespace() {
  print_section "Setting up Kubernetes namespace"
  
  if kubectl get namespace $NAMESPACE &> /dev/null; then
    print_info "Namespace $NAMESPACE already exists"
  else
    kubectl create namespace $NAMESPACE
    print_success "Created namespace $NAMESPACE"
  fi
  
  # Apply base configuration
  kubectl apply -f k8s/manifests/00-namespace.yaml
  kubectl apply -f k8s/manifests/01-configmap.yaml
  
  print_success "Namespace setup completed"
}

# Function to generate certificates
generate_certificates() {
  print_section "Generating Fabric certificates"
  
  # Create crypto directory
  mkdir -p crypto-config
  
  # Create secrets required for certificate generation
  kubectl apply -f k8s/manifests/01a-fabric-secrets.yaml
  
  # Apply Fabric CA job for certificate generation
  kubectl apply -f k8s/manifests/01c-fabric-ca-job.yaml
  
  print_info "Waiting for certificate generation job to complete..."
  kubectl wait --for=condition=complete --timeout=300s job/fabric-ca-cert-generation -n $NAMESPACE || print_error "Certificate generation job failed"
  
  print_success "Certificates generated successfully"
  
  # Create the crypto-config ConfigMap
  kubectl apply -f k8s/manifests/01b-crypto-config.yaml
  print_success "Crypto configuration applied"
}

# Function to deploy Fabric components
deploy_fabric() {
  print_section "Deploying Hyperledger Fabric components"
  
  kubectl apply -f k8s/manifests/02-fabric.yaml
  
  print_info "Waiting for Fabric components to be ready..."
  
  # Wait for deployments to be ready
  kubectl wait --namespace $NAMESPACE --for=condition=available --timeout=300s deployment/ca-org1 || print_info "Timed out waiting for ca-org1"
  kubectl wait --namespace $NAMESPACE --for=condition=available --timeout=300s deployment/orderer || print_info "Timed out waiting for orderer"
  kubectl wait --namespace $NAMESPACE --for=condition=available --timeout=300s deployment/peer0-org1 || print_info "Timed out waiting for peer0-org1"
  
  print_success "Fabric components deployed successfully"
}

# Function to create a channel
create_channel() {
  print_section "Creating Hyperledger Fabric channel"
  
  # Run the channel creation script
  print_info "Creating the mediblock-channel..."
  ./scripts/create-channel.sh || print_error "Channel creation failed"
  
  print_success "Channel created successfully"
}

# Function to deploy application services
deploy_services() {
  print_section "Deploying application services"
  
  # Deploy IPFS
  print_info "Deploying IPFS..."
  kubectl apply -f k8s/manifests/03-ipfs.yaml
  
  # Deploy Go service
  print_info "Deploying Go service..."
  kubectl apply -f k8s/manifests/04-go-service.yaml
  
  # Deploy Python service
  print_info "Deploying Python service..."
  kubectl apply -f k8s/manifests/05-python-service.yaml
  
  # Deploy Next.js frontend
  print_info "Deploying NextJS frontend..."
  kubectl apply -f k8s/manifests/06-nextjs-frontend.yaml
  
  # Wait for services to be ready
  print_info "Waiting for services to be ready..."
  kubectl wait --namespace $NAMESPACE --for=condition=available --timeout=300s deployment/go-service || print_info "Timed out waiting for go-service"
  kubectl wait --namespace $NAMESPACE --for=condition=available --timeout=300s deployment/python-service || print_info "Timed out waiting for python-service"
  kubectl wait --namespace $NAMESPACE --for=condition=available --timeout=300s deployment/nextjs-frontend || print_info "Timed out waiting for nextjs-frontend"
  
  print_success "Application services deployed successfully"
}

# Function to display access information
display_access_info() {
  print_section "Deployment completed successfully"
  
  # Get frontend URL
  FRONTEND_PORT=$(kubectl get service nextjs-frontend -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "Not available yet")
  if [[ -n "$FRONTEND_PORT" && "$FRONTEND_PORT" != "Not available yet" ]]; then
    FRONTEND_URL="http://localhost:$FRONTEND_PORT"
    print_info "Access the application frontend at: $FRONTEND_URL"
  else
    print_info "Frontend service not available with NodePort yet. Check status with:"
    print_info "   kubectl get services -n $NAMESPACE"
  fi
  
  print_info "To view logs:"
  print_info "   kubectl logs -n $NAMESPACE deployment/nextjs-frontend"
  print_info "   kubectl logs -n $NAMESPACE deployment/python-service"
  print_info "   kubectl logs -n $NAMESPACE deployment/go-service"
  print_info "   kubectl logs -n $NAMESPACE deployment/peer0-org1"
  print_info "   kubectl logs -n $NAMESPACE deployment/orderer"
  
  print_info "\nTo clean up resources:"
  print_info "   kubectl delete namespace $NAMESPACE"
}

# Main execution flow
main() {
  print_section "Starting MediBlock Deployment"
  
  check_prerequisites
  build_images
  setup_namespace
  generate_certificates
  deploy_fabric
  create_channel
  deploy_services
  display_access_info
}

main "$@" 