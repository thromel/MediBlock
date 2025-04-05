#!/bin/bash

# Exit on first error
set -e

# Output directory
OUTPUT_DIR="./crypto-config-fixed"

echo "Generating fixed Fabric certificates in directory: $OUTPUT_DIR"

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
# CA cert: needs keyCertSign and cRLSign
basicConstraints   = critical, CA:true, pathlen:1
keyUsage           = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash

[ v3_req ]
# Default extensions if not overridden (less relevant here)
keyUsage           = critical, digitalSignature, keyEncipherment
extendedKeyUsage   = serverAuth, clientAuth
basicConstraints   = critical, CA:true, pathlen:1
subjectKeyIdentifier = hash

[ orderer_ext ]
# Orderer cert: Needs signing and client/server auth
keyUsage           = critical, digitalSignature, keyEncipherment
extendedKeyUsage   = serverAuth, clientAuth
basicConstraints   = CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
subjectAltName     = DNS:orderer.mediblock.com, DNS:orderer, DNS:localhost, IP:127.0.0.1

[ peer_ext ]
# Peer cert: Needs signing and client/server auth
keyUsage           = critical, digitalSignature, keyEncipherment
extendedKeyUsage   = serverAuth, clientAuth
basicConstraints   = CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
subjectAltName     = DNS:peer0.org1.mediblock.com, DNS:peer0-org1, DNS:localhost, IP:127.0.0.1

[ admin_ext ]
# Admin cert: Needs signing and client auth
keyUsage           = critical, digitalSignature
extendedKeyUsage   = clientAuth
basicConstraints   = CA:false
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

echo "Certificates generated successfully in $OUTPUT_DIR"
echo "Now you need to create Kubernetes secrets with these certificates" 