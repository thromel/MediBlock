#!/bin/bash

# Exit on any error
set -e

echo "Setting up Fabric certificates using Fabric CA..."

# Delete any existing job and resources
kubectl delete job fabric-ca-cert-generation -n mediblock --ignore-not-found=true
kubectl delete secret orderer-msp-secret peer0-org1-msp-secret orderer-tls peer0-org1-tls -n mediblock --ignore-not-found=true
kubectl delete configmap orderer-msp peer0-org1-msp -n mediblock --ignore-not-found=true
kubectl delete pod cert-access -n mediblock --ignore-not-found=true

# Apply the job
echo "Applying job for certificate generation..."
kubectl apply -f k8s/manifests/01c-fabric-ca-job.yaml

# Wait for job to complete
echo "Waiting for job to complete..."
kubectl wait --for=condition=complete job/fabric-ca-cert-generation -n mediblock --timeout=300s

# Create a helper pod to access the PVC
echo "Creating helper pod to access certificates..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cert-access
  namespace: mediblock
spec:
  serviceAccountName: fabric-cert-generator
  volumes:
  - name: cert-volume
    persistentVolumeClaim:
      claimName: fabric-ca-certs-pvc
  containers:
  - name: cert-access
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: cert-volume
      mountPath: /certs
EOF

# Wait for helper pod to be ready
echo "Waiting for helper pod to be ready..."
kubectl wait --for=condition=Ready pod/cert-access -n mediblock --timeout=60s

# Create secrets and configmaps
echo "Creating secrets and configmaps from the helper pod..."
kubectl exec -n mediblock cert-access -- bash -c "
# Orderer MSP
kubectl create secret generic orderer-msp-secret -n mediblock --from-file=key.pem=/certs/orderer/msp/keystore/key.pem
kubectl create configmap orderer-msp -n mediblock \
  --from-file=cacerts-ca.crt=/certs/orderer/msp/cacerts/ca.crt \
  --from-file=signcerts-cert.pem=/certs/orderer/msp/signcerts/cert.pem \
  --from-file=admincerts-cert.pem=/certs/orderer/msp/admincerts/admin.crt \
  --from-file=tlscacerts-ca.crt=/certs/orderer/msp/tlscacerts/ca.crt \
  --from-file=config.yaml=/certs/orderer/msp/config.yaml

# Peer MSP
kubectl create secret generic peer0-org1-msp-secret -n mediblock --from-file=key.pem=/certs/peer0-org1/msp/keystore/key.pem
kubectl create configmap peer0-org1-msp -n mediblock \
  --from-file=cacerts-ca.crt=/certs/peer0-org1/msp/cacerts/ca.crt \
  --from-file=signcerts-cert.pem=/certs/peer0-org1/msp/signcerts/cert.pem \
  --from-file=admincerts-cert.pem=/certs/peer0-org1/msp/admincerts/admin.crt \
  --from-file=tlscacerts-ca.crt=/certs/peer0-org1/msp/tlscacerts/ca.crt \
  --from-file=config.yaml=/certs/peer0-org1/msp/config.yaml

# TLS Secrets
kubectl create secret generic orderer-tls -n mediblock \
  --from-file=server.crt=/certs/orderer/tls/server.crt \
  --from-file=server.key=/certs/orderer/tls/server.key \
  --from-file=ca.crt=/certs/orderer/tls/ca.crt

kubectl create secret generic peer0-org1-tls -n mediblock \
  --from-file=server.crt=/certs/peer0-org1/tls/server.crt \
  --from-file=server.key=/certs/peer0-org1/tls/server.key \
  --from-file=ca.crt=/certs/peer0-org1/tls/ca.crt
"

# Create a pod to deploy certificates to the right locations
echo "Creating a pod to deploy certificates to the right locations..."
kubectl exec -n mediblock cert-access -- bash -c "
# Create ConfigMap for orderer file locations
kubectl create configmap orderer-file-locations -n mediblock --from-literal=msp-path=/var/hyperledger/production/orderer/msp --from-literal=tls-path=/var/hyperledger/fabric/config/tls

# Create ConfigMap for peer file locations
kubectl create configmap peer0-org1-file-locations -n mediblock --from-literal=msp-path=/var/hyperledger/production/peer/msp --from-literal=tls-path=/var/hyperledger/fabric/config/tls
"

# Delete helper pod
echo "Deleting helper pod..."
kubectl delete pod cert-access -n mediblock

# Restart required deployments
echo "Restarting orderer and peer deployments..."
kubectl rollout restart deployment/orderer -n mediblock
kubectl rollout restart deployment/peer0-org1 -n mediblock

echo "Certificate setup complete."
echo "Use 'kubectl get pods -n mediblock' to check the status of the pods." 