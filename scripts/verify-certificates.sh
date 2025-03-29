#!/bin/bash
set -e

echo "Verifying Fabric certificates in the Kubernetes cluster..."

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Extract certificates from secrets
echo "Extracting certificates from secrets..."
echo "Orderer certificates:"
kubectl get secret orderer-msp-secret -n mediblock -o jsonpath='{.data.ca\.crt}' | base64 --decode > "$TMP_DIR/orderer-ca.crt"
kubectl get secret orderer-msp-secret -n mediblock -o jsonpath='{.data.cert\.pem}' | base64 --decode > "$TMP_DIR/orderer-cert.pem"

echo "Peer certificates:"
kubectl get secret peer0-org1-msp-secret -n mediblock -o jsonpath='{.data.ca\.crt}' | base64 --decode > "$TMP_DIR/peer-ca.crt"
kubectl get secret peer0-org1-msp-secret -n mediblock -o jsonpath='{.data.peer\.crt}' | base64 --decode > "$TMP_DIR/peer-cert.pem"

# Verify certificate signature algorithms
echo "Verifying certificate signature algorithms..."
echo "Orderer CA certificate:"
openssl x509 -in "$TMP_DIR/orderer-ca.crt" -noout -text | grep "Signature Algorithm"

echo "Orderer certificate:"
openssl x509 -in "$TMP_DIR/orderer-cert.pem" -noout -text | grep "Signature Algorithm"

echo "Peer CA certificate:"
openssl x509 -in "$TMP_DIR/peer-ca.crt" -noout -text | grep "Signature Algorithm"

echo "Peer certificate:"
openssl x509 -in "$TMP_DIR/peer-cert.pem" -noout -text | grep "Signature Algorithm"

# Verify certificate extensions (SANs)
echo "Verifying certificate extensions (Subject Alternative Names):"
echo "Orderer certificate SANs:"
openssl x509 -in "$TMP_DIR/orderer-cert.pem" -noout -text | grep -A2 "Subject Alternative Name"

echo "Peer certificate SANs:"
openssl x509 -in "$TMP_DIR/peer-cert.pem" -noout -text | grep -A2 "Subject Alternative Name"

echo "Certificate verification complete." 