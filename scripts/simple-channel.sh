#!/bin/bash
set -e

echo "Creating a channel using peer CLI directly"

# Create a pod with Fabric CLI tools
kubectl delete pod cli-pod -n mediblock --ignore-not-found
kubectl run cli-pod -n mediblock --image=hyperledger/fabric-tools:2.5.4 -- sleep 3600

# Wait for the pod to be ready
kubectl wait --for=condition=Ready pod/cli-pod -n mediblock --timeout=120s

# Set up MSP directories
echo "Setting up MSP directories"
kubectl exec -i cli-pod -n mediblock -- bash -c '
mkdir -p /tmp/msp/admincerts
mkdir -p /tmp/msp/cacerts
mkdir -p /tmp/msp/keystore
mkdir -p /tmp/msp/signcerts
mkdir -p /tmp/msp/tlscacerts
mkdir -p /tmp/msp/config
'

# Copy MSP files from configmap/secret
echo "Copying peer MSP files"
kubectl get configmap -n mediblock peer0-org1-msp -o jsonpath='{.data.admincerts-cert\.pem}' | kubectl exec -i cli-pod -n mediblock -- bash -c 'cat > /tmp/msp/admincerts/cert.pem'
kubectl get configmap -n mediblock peer0-org1-msp -o jsonpath='{.data.cacerts-ca\.crt}' | kubectl exec -i cli-pod -n mediblock -- bash -c 'cat > /tmp/msp/cacerts/ca.crt'
kubectl get configmap -n mediblock peer0-org1-msp -o jsonpath='{.data.signcerts-cert\.pem}' | kubectl exec -i cli-pod -n mediblock -- bash -c 'cat > /tmp/msp/signcerts/cert.pem'
kubectl get secret -n mediblock peer0-org1-msp-secret -o jsonpath='{.data.key\.pem}' | base64 -d | kubectl exec -i cli-pod -n mediblock -- bash -c 'cat > /tmp/msp/keystore/key.pem'
kubectl get configmap -n mediblock orderer-msp -o jsonpath='{.data.tlscacerts-ca\.crt}' | kubectl exec -i cli-pod -n mediblock -- bash -c 'cat > /tmp/msp/tlscacerts/ca.crt'
kubectl get configmap -n mediblock peer0-org1-msp -o jsonpath='{.data.config\.yaml}' | kubectl exec -i cli-pod -n mediblock -- bash -c 'cat > /tmp/msp/config/config.yaml'

# Create a configtx.yaml file
echo "Creating configtx.yaml for channel creation"
cat <<EOF | kubectl exec -i cli-pod -n mediblock -- bash -c 'cat > /configtx.yaml'
Organizations:
- &OrdererOrg
    Name: OrdererOrg
    ID: OrdererMSP
    MSPDir: /tmp/msp
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
    MSPDir: /tmp/msp
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
        <<: *ChannelDefaults
        Consortium: SampleConsortium
        Application:
            <<: *ApplicationDefaults
            Organizations:
                - *Org1
            Capabilities:
                <<: *ApplicationCapabilities
EOF

# Create a channel using the Fabric peer CLI
echo "Creating the channel using the orderer"
kubectl exec -i cli-pod -n mediblock -- bash -c '
export CORE_PEER_MSPCONFIGPATH=/tmp/msp
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_ADDRESS=peer0-org1:7051
export ORDERER_CA=/tmp/msp/tlscacerts/ca.crt

# Verify MSP directory
echo "MSP Directory Contents:"
ls -la /tmp/msp
ls -la /tmp/msp/cacerts
ls -la /tmp/msp/keystore
ls -la /tmp/msp/signcerts
ls -la /tmp/msp/tlscacerts
ls -la /tmp/msp/config

# Generate the genesis block for the channel
echo "Creating channel creation transaction..."
FABRIC_CFG_PATH=/ configtxgen -profile MediBlockApplicationChannel -outputCreateChannelTx /tmp/mediblock-channel.tx -channelID mediblock-channel

# Create the channel
echo "Creating the channel..."
peer channel create -o orderer:7050 -c mediblock-channel -f /tmp/mediblock-channel.tx --ordererTLSHostnameOverride orderer

# Join the peer to the channel
echo "Joining peer to the channel..."
peer channel join -b mediblock-channel.block

# List all channels
echo "Listing channels:"
peer channel list
'

echo "Channel creation completed!" 