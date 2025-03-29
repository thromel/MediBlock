# MediBlock - Healthcare Blockchain Platform

MediBlock is a healthcare blockchain platform that enables secure storage, sharing, and management of electronic health records (EHRs) with granular patient consent controls.

## Architecture

The platform is built with the following components:

- **Hyperledger Fabric**: The core permissioned blockchain network
- **Go Microservice**: Handles interactions with the blockchain through Fabric SDK
- **Python Microservice**: Manages cryptography, IPFS integration, and application logic
- **Next.js Frontend**: Progressive Web App (PWA) for user interactions
- **IPFS**: Off-chain storage for larger medical files/data

## Development Environment Setup

### Prerequisites

- Docker and Docker Compose
- Git
- Node.js (v16+) and npm
- Go (v1.16+)
- Python (v3.9+)

### Getting Started

1. Clone the repository:

```bash
git clone https://github.com/yourusername/MediBlock.git
cd MediBlock
```

2. Generate the Fabric certificates and configuration:

```bash
chmod +x scripts/generate-fabric-certs.sh
./scripts/generate-fabric-certs.sh
```

3. Start the local blockchain network and services:

```bash
docker-compose up -d
```

This will spin up:
- Hyperledger Fabric network (CA, orderer, peer)
- IPFS node
- Fabric CLI for chaincode operations

4. Install and start the Go microservice:

```bash
cd go-service
go mod tidy
go run main.go
```

5. Install and start the Python microservice:

```bash
cd python-service
pip install -r requirements.txt
flask run --host=0.0.0.0 --port=5000
```

6. Install and start the Next.js frontend:

```bash
cd nextjs-frontend
npm install
npm run dev
```

The frontend will be available at http://localhost:3000

### Kubernetes Deployment

For deploying to Kubernetes:

1. Create the namespace and apply certificates:

```bash
kubectl apply -f k8s/manifests/00-namespace.yaml
./scripts/update-fabric-certs.sh
```

2. Apply the remaining manifests:

```bash
kubectl apply -f k8s/manifests/
```

For more details on certificate management, see [Certificate Management](docs/CERTIFICATE_MANAGEMENT.md).

## Development Workflow

### Chaincode Development

The Hyperledger Fabric chaincode is located in the `chaincode/ehrmanager` directory. It contains the smart contract for EHR management, including:

- User registration
- Record storage and retrieval
- Consent management

To update and deploy the chaincode:

1. Make changes to the `chaincode/ehrmanager/ehrmanager.go` file
2. Use the Fabric CLI to install and upgrade the chaincode:

```bash
docker exec -it cli bash
cd /opt/gopath/src/github.com/chaincode/ehrmanager
peer lifecycle chaincode package ehrmanager.tar.gz --path . --lang golang --label ehrmanager_1.0
peer lifecycle chaincode install ehrmanager.tar.gz
# Additional commands for chaincode approval and commit
```

### API Services

The Go and Python microservices provide RESTful APIs for the frontend:

- Go service (8081): Blockchain interactions
- Python service (5000): File handling, encryption, and IPFS

API endpoints include:
- `/api/users` - User registration
- `/api/records` - Upload/retrieve records
- `/api/consent` - Manage consent

### Frontend Development

The Next.js frontend in `nextjs-frontend` provides a user interface for:
- User registration
- Record upload
- Record retrieval
- Consent management

## Testing

Run tests for each component:

```bash
# Chaincode tests
cd chaincode/ehrmanager
go test -v ./...

# Go service tests
cd go-service
go test -v ./...

# Python service tests
cd python-service
pytest

# Frontend tests
cd nextjs-frontend
npm test
```

## CI/CD

The project uses GitHub Actions for continuous integration. Each commit triggers:
- Chaincode tests
- Go service tests
- Python service tests
- Frontend linting

## License

[MIT License](LICENSE)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Additional Resources

- [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
- [IPFS Documentation](https://docs.ipfs.io/)
- [Next.js Documentation](https://nextjs.org/docs) 