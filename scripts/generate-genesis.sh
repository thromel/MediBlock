#!/bin/bash

# Exit on any error
set -e

echo "Generating genesis block..."

# Delete any existing helper pod
kubectl delete pod genesis-generator -n mediblock --ignore-not-found=true

# Create a helper pod to access the PVC and run configtxgen
echo "Creating helper pod to generate genesis block..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: genesis-generator
  namespace: mediblock
spec:
  serviceAccountName: fabric-cert-generator
  volumes:
  - name: cert-volume
    persistentVolumeClaim:
      claimName: fabric-ca-certs-pvc
  - name: config-volume
    configMap:
      name: configtx-config
  containers:
  - name: configtxgen
    image: hyperledger/fabric-tools:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: cert-volume
      mountPath: /certs
    - name: config-volume
      mountPath: /etc/hyperledger/fabric/configtx.yaml
      subPath: configtx.yaml
EOF

# Create configmap for configtx.yaml
kubectl create configmap configtx-config -n mediblock --from-file=configtx.yaml=config/configtx.yaml --dry-run=client -o yaml | kubectl apply -f -

# Wait for helper pod to be ready
echo "Waiting for helper pod to be ready..."
kubectl wait --for=condition=Ready pod/genesis-generator -n mediblock --timeout=60s

# Generate genesis block
echo "Generating genesis block..."
kubectl exec -n mediblock genesis-generator -- bash -c "
mkdir -p /etc/hyperledger/fabric
configtxgen -profile TwoOrgsOrdererGenesis -channelID system-channel -outputBlock /certs/genesis.block -configPath /etc/hyperledger/fabric
configtxgen -profile TwoOrgsChannel -channelID medichannelid -outputCreateChannelTx /certs/channel.tx -configPath /etc/hyperledger/fabric
"

# Create a configmap for the genesis block
echo "Creating configmap for genesis block..."
kubectl exec -n mediblock genesis-generator -- bash -c "
mkdir -p /certs/genesis-extract
cp /certs/genesis.block /certs/genesis-extract/genesisblock
cp /certs/channel.tx /certs/genesis-extract/channel.tx
"

# Delete configtxgen pod
kubectl delete pod genesis-generator -n mediblock

# Create kubectl pod to create configmap
echo "Creating kubectl pod to create configmap..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: kubectl-pod
  namespace: mediblock
spec:
  serviceAccountName: fabric-cert-generator
  volumes:
  - name: cert-volume
    persistentVolumeClaim:
      claimName: fabric-ca-certs-pvc
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: cert-volume
      mountPath: /certs
EOF

# Wait for kubectl pod to be ready
echo "Waiting for kubectl pod to be ready..."
kubectl wait --for=condition=Ready pod/kubectl-pod -n mediblock --timeout=60s

# Create configmap from the genesis block
echo "Creating configmap from the genesis block..."
kubectl exec -n mediblock kubectl-pod -- bash -c "
kubectl create configmap fabric-genesis -n mediblock --from-file=genesisblock=/certs/genesis-extract/genesisblock --from-file=channel.tx=/certs/genesis-extract/channel.tx
"

# Delete kubectl pod
echo "Deleting kubectl pod..."
kubectl delete pod kubectl-pod -n mediblock

# Create configmap for orderer to find the genesis block
kubectl create configmap orderer-config -n mediblock --from-literal=genesis-file-path=/var/hyperledger/fabric/config/genesisblock --dry-run=client -o yaml | kubectl apply -f -

# Restart required deployments to use the new genesis block
echo "Restarting orderer deployment..."
kubectl rollout restart deployment/orderer -n mediblock

echo "Genesis block setup complete."
echo "Use 'kubectl get pods -n mediblock' to check the status of the pods." 