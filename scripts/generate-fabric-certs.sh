#!/bin/bash

# Exit on first error
set -e

# Default output directory
OUTPUT_DIR="./crypto-config"

# Function to print usage information
function print_usage() {
  echo "Usage: $0 [-o OUTPUT_DIR]"
  echo "  -o OUTPUT_DIR: Directory to store generated certificates (default: $OUTPUT_DIR)"
  echo "  -h: Show this help message"
}

# Parse command line arguments
while getopts "o:h" opt; do
  case $opt in
    o)
      OUTPUT_DIR=$OPTARG
      ;;
    h)
      print_usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      print_usage
      exit 1
      ;;
  esac
done

echo "Generating Fabric certificates in directory: $OUTPUT_DIR"

# Create necessary directories
mkdir -p $OUTPUT_DIR/ca
mkdir -p $OUTPUT_DIR/orderer/msp/admincerts
mkdir -p $OUTPUT_DIR/orderer/msp/cacerts
mkdir -p $OUTPUT_DIR/orderer/msp/keystore
mkdir -p $OUTPUT_DIR/orderer/msp/signcerts
mkdir -p $OUTPUT_DIR/orderer/msp/tlscacerts
mkdir -p $OUTPUT_DIR/peer0-org1/msp/admincerts
mkdir -p $OUTPUT_DIR/peer0-org1/msp/cacerts
mkdir -p $OUTPUT_DIR/peer0-org1/msp/keystore
mkdir -p $OUTPUT_DIR/peer0-org1/msp/signcerts
mkdir -p $OUTPUT_DIR/peer0-org1/msp/tlscacerts

# Create MSP config files
mkdir -p $OUTPUT_DIR/orderer/msp
mkdir -p $OUTPUT_DIR/peer0-org1/msp

cat > $OUTPUT_DIR/orderer/msp/config.yaml << EOF
NodeOUs:
  Enable: false
EOF

cat > $OUTPUT_DIR/peer0-org1/msp/config.yaml << EOF
NodeOUs:
  Enable: false
EOF

# Generate OpenSSL configuration file with proper extensions for Fabric
cat > $OUTPUT_DIR/openssl.cnf << EOF
[ req ]
default_bits       = 256
default_md         = sha256
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[ req_distinguished_name ]
C                  = US
ST                 = California
L                  = San Francisco
O                  = MediBlock
OU                 = Hyperledger Fabric
CN                 = fabric-ca

[ v3_ca ]
basicConstraints   = critical, CA:true, pathlen:1
keyUsage           = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash

[ v3_req ]
keyUsage           = critical, digitalSignature, keyEncipherment, keyCertSign, cRLSign
extendedKeyUsage   = serverAuth, clientAuth
basicConstraints   = critical, CA:true, pathlen:1
subjectKeyIdentifier = hash

[ orderer_ext ]
keyUsage           = critical, digitalSignature, keyEncipherment
extendedKeyUsage   = serverAuth, clientAuth
basicConstraints   = critical, CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
subjectAltName     = DNS:orderer.mediblock.com, DNS:orderer, DNS:localhost, IP:127.0.0.1

[ peer_ext ]
keyUsage           = critical, digitalSignature, keyEncipherment
extendedKeyUsage   = serverAuth, clientAuth
basicConstraints   = critical, CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
subjectAltName     = DNS:peer0.org1.mediblock.com, DNS:peer0-org1, DNS:localhost, IP:127.0.0.1

[ admin_ext ]
keyUsage           = critical, digitalSignature
extendedKeyUsage   = clientAuth
basicConstraints   = critical, CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

# 1. Generate Root CA Certificate
echo "Generating Root CA certificate..."
openssl ecparam -name prime256v1 -genkey -noout -out $OUTPUT_DIR/ca/ca.key
openssl req -new -x509 -key $OUTPUT_DIR/ca/ca.key -out $OUTPUT_DIR/ca/ca.crt -days 3650 \
  -config $OUTPUT_DIR/openssl.cnf \
  -extensions v3_ca \
  -sha256

# 2. Generate Orderer certificates
echo "Generating Orderer certificates..."
openssl ecparam -name prime256v1 -genkey -noout -out $OUTPUT_DIR/orderer/msp/keystore/key.pem
openssl req -new -key $OUTPUT_DIR/orderer/msp/keystore/key.pem -out $OUTPUT_DIR/orderer/orderer.csr \
  -subj "/C=US/ST=California/L=San Francisco/O=MediBlock/OU=Orderer/CN=orderer.mediblock.com" \
  -config $OUTPUT_DIR/openssl.cnf \
  -sha256

openssl x509 -req -in $OUTPUT_DIR/orderer/orderer.csr -CA $OUTPUT_DIR/ca/ca.crt -CAkey $OUTPUT_DIR/ca/ca.key \
  -CAcreateserial -out $OUTPUT_DIR/orderer/msp/signcerts/cert.pem -days 3650 \
  -extensions orderer_ext -extfile $OUTPUT_DIR/openssl.cnf \
  -sha256

# 3. Generate Peer certificates
echo "Generating Peer certificates..."
openssl ecparam -name prime256v1 -genkey -noout -out $OUTPUT_DIR/peer0-org1/msp/keystore/key.pem
openssl req -new -key $OUTPUT_DIR/peer0-org1/msp/keystore/key.pem -out $OUTPUT_DIR/peer0-org1/peer.csr \
  -subj "/C=US/ST=California/L=San Francisco/O=MediBlock/OU=Peer/CN=peer0.org1.mediblock.com" \
  -config $OUTPUT_DIR/openssl.cnf \
  -sha256

openssl x509 -req -in $OUTPUT_DIR/peer0-org1/peer.csr -CA $OUTPUT_DIR/ca/ca.crt -CAkey $OUTPUT_DIR/ca/ca.key \
  -CAcreateserial -out $OUTPUT_DIR/peer0-org1/msp/signcerts/cert.pem -days 3650 \
  -extensions peer_ext -extfile $OUTPUT_DIR/openssl.cnf \
  -sha256

# 4. Generate Admin certificate
echo "Generating Admin certificate..."
openssl ecparam -name prime256v1 -genkey -noout -out $OUTPUT_DIR/admin.key
openssl req -new -key $OUTPUT_DIR/admin.key -out $OUTPUT_DIR/admin.csr \
  -subj "/C=US/ST=California/L=San Francisco/O=MediBlock/OU=Admin/CN=admin.mediblock.com" \
  -config $OUTPUT_DIR/openssl.cnf \
  -sha256

openssl x509 -req -in $OUTPUT_DIR/admin.csr -CA $OUTPUT_DIR/ca/ca.crt -CAkey $OUTPUT_DIR/ca/ca.key \
  -CAcreateserial -out $OUTPUT_DIR/admin.crt -days 3650 \
  -extensions admin_ext -extfile $OUTPUT_DIR/openssl.cnf \
  -sha256

# 5. Copy certificates to the appropriate directories
cp $OUTPUT_DIR/ca/ca.crt $OUTPUT_DIR/orderer/msp/cacerts/
cp $OUTPUT_DIR/ca/ca.crt $OUTPUT_DIR/peer0-org1/msp/cacerts/
cp $OUTPUT_DIR/admin.crt $OUTPUT_DIR/orderer/msp/admincerts/
cp $OUTPUT_DIR/admin.crt $OUTPUT_DIR/peer0-org1/msp/admincerts/

echo "Creating Kubernetes ConfigMaps and Secrets..."

# Create the ConfigMap manifest
cat > k8s/manifests/01b-crypto-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: fabric-config
  namespace: mediblock
data:
  core.yaml: |
    peer:
      id: peer0
      networkId: mediblock
      listenAddress: 0.0.0.0:7051
      chaincodeListenAddress: 0.0.0.0:7052
      address: 0.0.0.0:7051
      gossip:
        bootstrap: peer0-org1:7051
        endpoint: peer0-org1:7051
        externalEndpoint: peer0-org1:7051
      tls:
        enabled: false
      mspConfigPath: /var/hyperledger/production/peer/msp
    ledger:
      state:
        stateDatabase: goleveldb
      history:
        enableHistoryDatabase: true
    chaincode:
      logging:
        level: info
    
  orderer.yaml: |
    General:
      ListenAddress: 0.0.0.0
      ListenPort: 7050
      TLS:
        Enabled: false
      LogLevel: info
      GenesisMethod: none
      LocalMSPDir: /var/hyperledger/production/orderer/msp
      LocalMSPID: OrdererMSP
    FileLedger:
      Location: /var/hyperledger/production/orderer
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: orderer-msp
  namespace: mediblock
data:
  cacerts-ca.crt: |
$(cat $OUTPUT_DIR/orderer/msp/cacerts/ca.crt | sed 's/^/    /')
  keystore-key.pem: |
$(cat $OUTPUT_DIR/orderer/msp/keystore/key.pem | sed 's/^/    /')
  signcerts-cert.pem: |
$(cat $OUTPUT_DIR/orderer/msp/signcerts/cert.pem | sed 's/^/    /')
  admincerts-cert.pem: |
$(cat $OUTPUT_DIR/orderer/msp/admincerts/admin.crt | sed 's/^/    /')
  config.yaml: |
$(cat $OUTPUT_DIR/orderer/msp/config.yaml | sed 's/^/    /')
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: peer0-org1-msp
  namespace: mediblock
data:
  cacerts-ca.crt: |
$(cat $OUTPUT_DIR/peer0-org1/msp/cacerts/ca.crt | sed 's/^/    /')
  keystore-key.pem: |
$(cat $OUTPUT_DIR/peer0-org1/msp/keystore/key.pem | sed 's/^/    /')
  signcerts-cert.pem: |
$(cat $OUTPUT_DIR/peer0-org1/msp/signcerts/cert.pem | sed 's/^/    /')
  admincerts-cert.pem: |
$(cat $OUTPUT_DIR/peer0-org1/msp/admincerts/admin.crt | sed 's/^/    /')
  config.yaml: |
$(cat $OUTPUT_DIR/peer0-org1/msp/config.yaml | sed 's/^/    /')
EOF

# Create Secrets
cat > k8s/manifests/01a-fabric-secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: orderer-msp-secret
  namespace: mediblock
type: Opaque
data:
  ca.crt: $(cat $OUTPUT_DIR/orderer/msp/cacerts/ca.crt | base64 | tr -d '\n')
  cert.pem: $(cat $OUTPUT_DIR/orderer/msp/signcerts/cert.pem | base64 | tr -d '\n')
  key.pem: $(cat $OUTPUT_DIR/orderer/msp/keystore/key.pem | base64 | tr -d '\n')
  admincert.pem: $(cat $OUTPUT_DIR/orderer/msp/admincerts/admin.crt | base64 | tr -d '\n')
---
apiVersion: v1
kind: Secret
metadata:
  name: peer0-org1-msp-secret
  namespace: mediblock
type: Opaque
data:
  ca.crt: $(cat $OUTPUT_DIR/peer0-org1/msp/cacerts/ca.crt | base64 | tr -d '\n')
  peer.crt: $(cat $OUTPUT_DIR/peer0-org1/msp/signcerts/cert.pem | base64 | tr -d '\n')
  peer.key: $(cat $OUTPUT_DIR/peer0-org1/msp/keystore/key.pem | base64 | tr -d '\n')
  admincert.pem: $(cat $OUTPUT_DIR/peer0-org1/msp/admincerts/admin.crt | base64 | tr -d '\n')
EOF

echo "Done! Certificates generated successfully."
echo "Kubernetes manifests created at:"
echo "  - k8s/manifests/01a-fabric-secrets.yaml"
echo "  - k8s/manifests/01b-crypto-config.yaml"

# Output details of generated certificates
echo "Verifying certificate details:"
openssl x509 -in $OUTPUT_DIR/ca/ca.crt -text -noout | grep "Signature Algorithm"
openssl x509 -in $OUTPUT_DIR/orderer/msp/signcerts/cert.pem -text -noout | grep "Signature Algorithm"
openssl x509 -in $OUTPUT_DIR/peer0-org1/msp/signcerts/cert.pem -text -noout | grep "Signature Algorithm"

echo "Certificate generation completed successfully"
echo "Kubernetes manifests created at k8s/manifests/01a-fabric-secrets.yaml and k8s/manifests/01b-crypto-config.yaml" 