# MediBlock Deployment Guide

This guide documents the deployment process for the MediBlock system on Kubernetes, including fixes for known issues with Hyperledger Fabric components.

## Prerequisites

- Kubernetes cluster (Docker Desktop for local development)
- kubectl configured to connect to your cluster
- Hyperledger Fabric tools

## Deployment Steps

Follow these steps to deploy the MediBlock system:

### 1. Apply Base Kubernetes Resources

```bash
# Create namespace
kubectl apply -f k8s/manifests/00-namespace.yaml

# Create base configmaps
kubectl apply -f k8s/manifests/01-configmap.yaml
```

### 2. Generate Certificates

The certificates needed for Hyperledger Fabric must be generated with the correct key usage settings:

```bash
# Generate certificates using Fabric CA
./scripts/apply-fabric-ca-certs.sh
```

### 3. Create Configuration Files

Create the following configuration files:

**orderer-config.yaml:**
```yaml
General:
  ListenAddress: 0.0.0.0
  ListenPort: 7050
  TLS:
    Enabled: false
  GenesisMethod: file
  GenesisFile: /var/hyperledger/fabric/config/genesisblock
  BootstrapMethod: file
  BootstrapFile: /var/hyperledger/fabric/config/genesisblock
  LocalMSPDir: /var/hyperledger/production/orderer/msp
  LocalMSPID: MediBlockMSP
FileLedger:
  Location: /var/hyperledger/production/orderer
```

**peer-config.yaml:**
```yaml
peer:
  id: peer0-org1
  networkId: mediblock
  listenAddress: 0.0.0.0:7051
  chaincodeListenAddress: 0.0.0.0:7052
  address: peer0-org1:7051
  gossip:
    bootstrap: peer0-org1:7051
    endpoint: peer0-org1:7051
    externalEndpoint: peer0-org1:7051
  tls:
    enabled: false
  mspConfigPath: /var/hyperledger/production/peer/msp
  localMspId: MediBlockMSP

ledger:
  state:
    stateDatabase: goleveldb
  history:
    enableHistoryDatabase: true

chaincode:
  logging:
    level: info

BCCSP:
  Default: SW
  SW:
    Hash: SHA2
    Security: 256
    FileKeyStore:
      KeyStore:
```

Create ConfigMaps from these files:

```bash
kubectl create configmap orderer-yaml-config -n mediblock --from-file=orderer.yaml=orderer-config.yaml
kubectl create configmap peer-yaml-config -n mediblock --from-file=core.yaml=peer-config.yaml
```

### 4. Generate Genesis Block

```bash
# Generate the genesis block
./scripts/generate-genesis.sh
```

### 5. Deploy Orderer

Create a file named `orderer-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orderer
  namespace: mediblock
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orderer
  template:
    metadata:
      labels:
        app: orderer
    spec:
      volumes:
        - name: msp-volume
          configMap:
            name: orderer-msp
        - name: msp-secret-volume
          secret:
            secretName: orderer-msp-secret
        - name: empty-dir
          emptyDir: {}
        - name: genesis-volume
          configMap:
            name: fabric-genesis
        - name: config-dir
          emptyDir: {}
        - name: fabric-config-volume
          configMap:
            name: orderer-yaml-config
      initContainers:
        - name: setup-folders
          image: busybox
          command: ["/bin/sh", "-c"]
          args:
            - |
              mkdir -p /var/hyperledger/production/orderer/msp/keystore && mkdir -p /var/hyperledger/production/orderer/msp/cacerts && mkdir -p /var/hyperledger/production/orderer/msp/signcerts && mkdir -p /var/hyperledger/production/orderer/msp/admincerts && cp /msp-data/cacerts-ca.crt /var/hyperledger/production/orderer/msp/cacerts/ca.crt && cp /msp-secret-data/key.pem /var/hyperledger/production/orderer/msp/keystore/key.pem && cp /msp-data/signcerts-cert.pem /var/hyperledger/production/orderer/msp/signcerts/cert.pem && cp /msp-data/admincerts-cert.pem /var/hyperledger/production/orderer/msp/admincerts/cert.pem && mkdir -p /var/hyperledger/fabric/config && cp /genesis-data/genesisblock /var/hyperledger/fabric/config/genesisblock && chmod -R 777 /var/hyperledger/production && chmod -R 777 /var/hyperledger/fabric
          volumeMounts:
            - name: msp-volume
              mountPath: /msp-data
            - name: msp-secret-volume
              mountPath: /msp-secret-data
            - name: empty-dir
              mountPath: /var/hyperledger/production
            - name: genesis-volume
              mountPath: /genesis-data
            - name: config-dir
              mountPath: /var/hyperledger/fabric
      containers:
        - name: orderer
          image: hyperledger/fabric-orderer:2.5.4
          command: ["orderer"]
          ports:
            - containerPort: 7050
          env:
            - name: FABRIC_LOGGING_SPEC
              value: "debug"
            - name: FABRIC_CFG_PATH
              value: "/etc/hyperledger/fabric"
          volumeMounts:
            - name: empty-dir
              mountPath: /var/hyperledger/production
            - name: config-dir
              mountPath: /var/hyperledger/fabric
            - name: fabric-config-volume
              mountPath: /etc/hyperledger/fabric
```

Apply the orderer deployment:

```bash
kubectl apply -f orderer-deployment.yaml
```

### 6. Deploy Peer

Create a file named `peer-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: peer0-org1
  namespace: mediblock
spec:
  replicas: 1
  selector:
    matchLabels:
      app: peer0-org1
  template:
    metadata:
      labels:
        app: peer0-org1
    spec:
      volumes:
        - name: empty-dir
          emptyDir: {}
        - name: msp-volume
          configMap:
            name: peer0-org1-msp
        - name: msp-secret-volume
          secret:
            secretName: peer0-org1-msp-secret
        - name: config-volume
          configMap:
            name: peer-yaml-config
        - name: genesis-volume
          configMap:
            name: fabric-genesis
        - name: config-dir
          emptyDir: {}
      initContainers:
        - name: setup-folders
          image: busybox
          command: ["/bin/sh", "-c"]
          args:
            - |
              mkdir -p /var/hyperledger/production/peer/msp/keystore
              mkdir -p /var/hyperledger/production/peer/msp/cacerts
              mkdir -p /var/hyperledger/production/peer/msp/signcerts
              mkdir -p /var/hyperledger/production/peer/msp/admincerts
              cp /msp-data/cacerts-ca.crt /var/hyperledger/production/peer/msp/cacerts/ca.crt
              cp /msp-secret-data/key.pem /var/hyperledger/production/peer/msp/keystore/key.pem
              cp /msp-data/signcerts-cert.pem /var/hyperledger/production/peer/msp/signcerts/cert.pem
              cp /msp-data/admincerts-cert.pem /var/hyperledger/production/peer/msp/admincerts/cert.pem
              mkdir -p /var/hyperledger/fabric/config
              cp /genesis-data/channel.tx /var/hyperledger/fabric/config/channel.tx
              chmod -R 777 /var/hyperledger/production
              chmod -R 777 /var/hyperledger/fabric
          volumeMounts:
            - name: msp-volume
              mountPath: /msp-data
            - name: msp-secret-volume
              mountPath: /msp-secret-data
            - name: empty-dir
              mountPath: /var/hyperledger/production
            - name: genesis-volume
              mountPath: /genesis-data
            - name: config-dir
              mountPath: /var/hyperledger/fabric
      containers:
        - name: peer0-org1
          image: hyperledger/fabric-peer:2.5.4
          command: ["peer", "node", "start"]
          env:
            - name: CORE_VM_ENDPOINT
              value: unix:///host/var/run/docker.sock
            - name: CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE
              value: mediblock_default
            - name: FABRIC_LOGGING_SPEC
              value: info
            - name: CORE_PEER_TLS_ENABLED
              value: "false"
            - name: CORE_PEER_PROFILE_ENABLED
              value: "false"
            - name: CORE_PEER_GOSSIP_USELEADERELECTION
              value: "true"
            - name: CORE_PEER_GOSSIP_ORGLEADER
              value: "false"
            - name: CORE_PEER_GOSSIP_EXTERNALENDPOINT
              value: peer0-org1:7051
            - name: CORE_PEER_LOCALMSPID
              value: MediBlockMSP
            - name: CORE_PEER_MSPCONFIGPATH
              value: /var/hyperledger/production/peer/msp
            - name: CORE_PEER_GOSSIP_BOOTSTRAP
              value: peer0-org1:7051
            - name: CORE_PEER_ADDRESS
              value: peer0-org1:7051
            - name: CORE_PEER_LISTENADDRESS
              value: 0.0.0.0:7051
            - name: CORE_PEER_CHAINCODEADDRESS
              value: peer0-org1:7052
            - name: CORE_PEER_CHAINCODELISTENADDRESS
              value: 0.0.0.0:7052
            - name: CORE_PEER_ID
              value: peer0-org1
            - name: CORE_CHAINCODE_EXECUTETIMEOUT
              value: "300s"
            - name: CORE_PEER_BCCSP_DEFAULT
              value: SW
            - name: CORE_PEER_BCCSP_SW_HASH
              value: SHA2
            - name: CORE_PEER_BCCSP_SW_SECURITY
              value: "256"
          ports:
            - containerPort: 7051
          volumeMounts:
            - name: empty-dir
              mountPath: /var/hyperledger/production
            - name: config-volume
              mountPath: /etc/hyperledger/fabric/core.yaml
              subPath: core.yaml
            - name: config-dir
              mountPath: /var/hyperledger/fabric
```

Apply the peer deployment:

```bash
kubectl apply -f peer-deployment.yaml
```

### 7. Deploy Supporting Services

```bash
kubectl apply -f k8s/manifests/02-fabric.yaml
kubectl apply -f k8s/manifests/03-ipfs.yaml
kubectl apply -f k8s/manifests/04-go-service.yaml
kubectl apply -f k8s/manifests/05-python-service.yaml
kubectl apply -f k8s/manifests/06-nextjs-frontend.yaml
```

## Troubleshooting

### Key Issues Addressed

1. **Certificate Key Usage**: Ensure certificates have the correct key usage settings. The `apply-fabric-ca-certs.sh` script generates certificates with the proper settings.

2. **Genesis Block Mounting**: The orderer requires the genesis block to be properly mounted at the path specified in the configuration file. Our init container copies it to the correct location.

3. **BCCSP Configuration**: The peer requires proper BCCSP (Blockchain Cryptographic Service Provider) configuration. We've added this to the peer configuration file.

4. **Key Filename**: The peer expects the key file with a specific name. Our init container renames it appropriately when copying.

### Checking Pod Status

```bash
kubectl get pods -n mediblock
```

### Checking Logs

```bash
# Check orderer logs
kubectl logs -n mediblock <orderer-pod-name> -c orderer

# Check peer logs
kubectl logs -n mediblock <peer-pod-name> -c peer0-org1
```

## Script for Automated Deployment

To automate the deployment process, create a `deploy-mediblock.sh` script that includes all these steps. 