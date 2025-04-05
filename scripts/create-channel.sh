#!/bin/bash
set -e

echo "Creating a new channel named mediblock-channel"

# Create a configtx.yaml to define the channel
mkdir -p temp
cat << EOF > temp/configtx.yaml
Organizations:
  - &OrdererOrg
    Name: OrdererOrg
    ID: OrdererMSP
    MSPDir: /tmp/orderer-msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('OrdererMSP.member')"
      Writers:
        Type: Signature
        Rule: "OR('OrdererMSP.member')"
      Admins:
        Type: Signature
        Rule: "OR('OrdererMSP.admin')"
    OrdererEndpoints:
      - orderer:7050

  - &Org1
    Name: Org1MSP
    ID: Org1MSP
    MSPDir: /tmp/peer-msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('Org1MSP.admin', 'Org1MSP.peer', 'Org1MSP.client')"
      Writers:
        Type: Signature
        Rule: "OR('Org1MSP.admin', 'Org1MSP.client')"
      Admins:
        Type: Signature
        Rule: "OR('Org1MSP.admin')"
      Endorsement:
        Type: Signature
        Rule: "OR('Org1MSP.peer')"
    AnchorPeers:
      - Host: peer0-org1
        Port: 7051

Capabilities:
  Channel: &ChannelCapabilities
    V2_0: true
  Orderer: &OrdererCapabilities
    V2_0: true
  Application: &ApplicationCapabilities
    V2_0: true

Application: &ApplicationDefaults
  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    LifecycleEndorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
    Endorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
  Capabilities:
    <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
  OrdererType: solo
  Addresses:
    - orderer:7050
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 10
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 KB
  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    BlockValidation:
      Type: ImplicitMeta
      Rule: "ANY Writers"
  Capabilities:
    <<: *OrdererCapabilities

Channel: &ChannelDefaults
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
  Capabilities:
    <<: *ChannelCapabilities

Profiles:
  MediBlockApplicationChannel:
    Consortium: SampleConsortium
    <<: *ChannelDefaults
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - *Org1
      Capabilities:
        <<: *ApplicationCapabilities
EOF

# Create a helper pod for creating the channel
echo "Creating a helper pod for channel creation"
kubectl delete pod channel-creator -n mediblock --ignore-not-found
kubectl run channel-creator -n mediblock --image=hyperledger/fabric-tools:2.5.4 -- sleep 3600

echo "Waiting for the helper pod to be ready"
kubectl wait --for=condition=Ready pod/channel-creator -n mediblock --timeout=120s

echo "Copying configtx.yaml to the helper pod"
kubectl cp temp/configtx.yaml channel-creator:/configtx.yaml -n mediblock

# Prepare MSP directories
echo "Preparing MSP directories in the helper pod"
kubectl exec -n mediblock channel-creator -- sh -c "
mkdir -p /tmp/peer-msp/admincerts
mkdir -p /tmp/peer-msp/cacerts
mkdir -p /tmp/peer-msp/keystore
mkdir -p /tmp/peer-msp/signcerts
mkdir -p /tmp/peer-msp/tlscacerts
mkdir -p /tmp/peer-msp/config

mkdir -p /tmp/orderer-msp/admincerts
mkdir -p /tmp/orderer-msp/cacerts
mkdir -p /tmp/orderer-msp/keystore
mkdir -p /tmp/orderer-msp/signcerts
mkdir -p /tmp/orderer-msp/tlscacerts
mkdir -p /tmp/orderer-msp/config
"

echo "Getting MSP files from Kubernetes resources"
# Get peer MSP files
kubectl get configmap -n mediblock peer0-org1-msp -o jsonpath='{.data.admincerts-cert\.pem}' > temp/peer-admin-cert.pem
kubectl get configmap -n mediblock peer0-org1-msp -o jsonpath='{.data.cacerts-ca\.crt}' > temp/peer-ca.crt
kubectl get configmap -n mediblock peer0-org1-msp -o jsonpath='{.data.signcerts-cert\.pem}' > temp/peer-signcert.pem
kubectl get configmap -n mediblock peer0-org1-msp -o jsonpath='{.data.config\.yaml}' > temp/peer-config.yaml
kubectl get secret -n mediblock peer0-org1-msp-secret -o jsonpath='{.data.key\.pem}' | base64 -d > temp/peer-key.pem

# Get orderer MSP files
kubectl get configmap -n mediblock orderer-msp -o jsonpath='{.data.admincerts-cert\.pem}' > temp/orderer-admin-cert.pem
kubectl get configmap -n mediblock orderer-msp -o jsonpath='{.data.cacerts-ca\.crt}' > temp/orderer-ca.crt
kubectl get configmap -n mediblock orderer-msp -o jsonpath='{.data.signcerts-cert\.pem}' > temp/orderer-signcert.pem
kubectl get configmap -n mediblock orderer-msp -o jsonpath='{.data.config\.yaml}' > temp/orderer-config.yaml
kubectl get configmap -n mediblock orderer-msp -o jsonpath='{.data.tlscacerts-ca\.crt}' > temp/orderer-tlsca.crt
kubectl get secret -n mediblock orderer-msp-secret -o jsonpath='{.data.key\.pem}' | base64 -d > temp/orderer-key.pem

# Copy files to the helper pod
echo "Copying MSP files to the helper pod"
# Peer MSP
kubectl cp temp/peer-admin-cert.pem channel-creator:/tmp/peer-msp/admincerts/cert.pem -n mediblock
kubectl cp temp/peer-ca.crt channel-creator:/tmp/peer-msp/cacerts/ca.crt -n mediblock
kubectl cp temp/peer-key.pem channel-creator:/tmp/peer-msp/keystore/key.pem -n mediblock
kubectl cp temp/peer-signcert.pem channel-creator:/tmp/peer-msp/signcerts/cert.pem -n mediblock
kubectl cp temp/peer-ca.crt channel-creator:/tmp/peer-msp/tlscacerts/ca.crt -n mediblock
kubectl cp temp/peer-config.yaml channel-creator:/tmp/peer-msp/config/config.yaml -n mediblock

# Orderer MSP
kubectl cp temp/orderer-admin-cert.pem channel-creator:/tmp/orderer-msp/admincerts/cert.pem -n mediblock
kubectl cp temp/orderer-ca.crt channel-creator:/tmp/orderer-msp/cacerts/ca.crt -n mediblock
kubectl cp temp/orderer-key.pem channel-creator:/tmp/orderer-msp/keystore/key.pem -n mediblock
kubectl cp temp/orderer-signcert.pem channel-creator:/tmp/orderer-msp/signcerts/cert.pem -n mediblock
kubectl cp temp/orderer-ca.crt channel-creator:/tmp/orderer-msp/tlscacerts/ca.crt -n mediblock
kubectl cp temp/orderer-config.yaml channel-creator:/tmp/orderer-msp/config/config.yaml -n mediblock

# Copy orderer TLS CA cert for later use
kubectl cp temp/orderer-tlsca.crt channel-creator:/orderer-tlsca.crt -n mediblock

echo "Creating the channel creation transaction"
kubectl exec -n mediblock channel-creator -- sh -c "
export FABRIC_CFG_PATH=/
configtxgen -profile MediBlockApplicationChannel -outputCreateChannelTx /mediblock-channel.tx -channelID mediblock-channel
"

echo "Creating the channel"
kubectl exec -n mediblock channel-creator -- sh -c "
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=/tmp/peer-msp
export ORDERER_CA=/orderer-tlsca.crt
peer channel create -o orderer:7050 -c mediblock-channel -f /mediblock-channel.tx --tls --cafile \$ORDERER_CA
"

echo "Joining peer0-org1 to the channel"
kubectl exec -n mediblock channel-creator -- sh -c "
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=/tmp/peer-msp
export CORE_PEER_ADDRESS=peer0-org1:7051
export ORDERER_CA=/orderer-tlsca.crt
peer channel join -b mediblock-channel.block
"

echo "Updating the anchor peers"
kubectl exec -n mediblock channel-creator -- sh -c "
export FABRIC_CFG_PATH=/
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=/tmp/peer-msp
export CORE_PEER_ADDRESS=peer0-org1:7051
export ORDERER_CA=/orderer-tlsca.crt
configtxgen -profile MediBlockApplicationChannel -outputAnchorPeersUpdate /Org1MSPanchors.tx -channelID mediblock-channel -asOrg Org1MSP
peer channel update -o orderer:7050 -c mediblock-channel -f /Org1MSPanchors.tx --tls --cafile \$ORDERER_CA
"

echo "Cleaning up the helper pod"
kubectl delete pod channel-creator -n mediblock

echo "Channel creation completed successfully!" 