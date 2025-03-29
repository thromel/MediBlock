# Hyperledger Fabric Certificate Management

This document explains how to properly manage certificates for the Hyperledger Fabric components in the MediBlock project.

## Overview

Fabric uses X.509 certificates for identity and authentication. The certificates must be properly formatted with specific extensions and attributes for Fabric to work correctly. This project includes scripts and Kubernetes manifests to generate and deploy proper certificates.

## Certificate Generation Process

We've implemented two approaches for certificate generation:

1. **Local Generation**: Using the `scripts/generate-fabric-certs.sh` script
2. **Kubernetes Job**: Using the `k8s/manifests/01c-cert-job.yaml` job

### Method 1: Local Certificate Generation

The `generate-fabric-certs.sh` script generates certificates with proper extensions and creates the necessary Kubernetes manifests. This method is ideal for development or initial setup.

```bash
# Generate certificates and update Kubernetes manifests
./scripts/generate-fabric-certs.sh

# Or specify a different output directory
./scripts/generate-fabric-certs.sh -o /custom/path
```

The script will:
1. Generate a CA certificate with proper extensions
2. Generate orderer certificates with proper extensions
3. Generate peer certificates with proper extensions
4. Generate admin certificates
5. Create Kubernetes Secret and ConfigMap manifests

### Method 2: Kubernetes Job

For production environments or where you need to regenerate certificates directly within the Kubernetes cluster, use the certificate generation job:

```bash
# Apply the certificate job and update deployment
./scripts/update-fabric-certs.sh
```

This script will:
1. Apply the certificate generation job
2. Wait for the job to complete
3. Restart the orderer and peer pods to use the new certificates

## Certificate Requirements

The certificates are generated with the following requirements:

### CA Certificate
- KeyUsage: `critical, digitalSignature, keyEncipherment, keyCertSign, cRLSign`
- ExtendedKeyUsage: `serverAuth, clientAuth`
- BasicConstraints: `critical, CA:true, pathlen:1`

### Orderer Certificate
- KeyUsage: `critical, digitalSignature, keyEncipherment`
- ExtendedKeyUsage: `serverAuth, clientAuth`
- BasicConstraints: `critical, CA:false`
- SubjectAltName: `DNS:orderer.mediblock.com, DNS:orderer, DNS:localhost, IP:127.0.0.1`

### Peer Certificate
- KeyUsage: `critical, digitalSignature, keyEncipherment`
- ExtendedKeyUsage: `serverAuth, clientAuth`
- BasicConstraints: `critical, CA:false`
- SubjectAltName: `DNS:peer0.org1.mediblock.com, DNS:peer0-org1, DNS:localhost, IP:127.0.0.1`

## Troubleshooting

If you encounter certificate-related issues:

1. Check pod logs for specific errors:
   ```bash
   kubectl logs -n mediblock <pod-name>
   ```

2. Verify certificate format:
   ```bash
   # Extract and decode the certificate
   kubectl get secret -n mediblock orderer-msp-secret -o jsonpath='{.data.cert\.pem}' | base64 -d > /tmp/cert.pem
   # View certificate details
   openssl x509 -in /tmp/cert.pem -text -noout
   ```

3. Regenerate certificates if needed:
   ```bash
   ./scripts/update-fabric-certs.sh
   ```

## Certificate Expiration

The certificates are generated with a validity of 10 years (3650 days). For production environments, consider implementing a certificate rotation process to refresh certificates before they expire.

## Security Considerations

- In production environments, secure the CA private key
- Consider implementing certificate rotation strategies
- Use proper access controls for Kubernetes Secrets
- Review RBAC permissions for the certificate generator service account 