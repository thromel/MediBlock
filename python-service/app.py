import os
import json
import random
import string
import requests
from cryptography.fernet import Fernet
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# IPFS API configuration
IPFS_API_URL = os.getenv('IPFS_API_URL', 'http://ipfs:5001/api/v0')

# Go Service API configuration
GO_SERVICE_URL = os.getenv('GO_SERVICE_URL', 'http://go-service:8081/api')


@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy"}), 200


@app.route('/api/upload', methods=['POST'])
def upload_file():
    """
    Upload a file to IPFS, encrypt it with a symmetric key,
    encrypt that key with the patient's public key, and store
    references on blockchain via Go service.
    """
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400

    if 'patientId' not in request.form:
        return jsonify({"error": "Patient ID required"}), 400

    file = request.files['file']
    patient_id = request.form['patientId']

    # Read file data
    file_data = file.read()

    # Generate a symmetric key for file encryption
    sym_key = Fernet.generate_key()
    fernet = Fernet(sym_key)

    # Encrypt the file
    encrypted_file = fernet.encrypt(file_data)

    # Upload encrypted file to IPFS
    files = {'file': ('encrypted_file', encrypted_file)}
    response = requests.post(f"{IPFS_API_URL}/add", files=files)

    if response.status_code != 200:
        return jsonify({"error": "Failed to upload to IPFS"}), 500

    ipfs_hash = response.json()['Hash']

    # In a real implementation, we would get the patient's public key
    # from the blockchain and encrypt the symmetric key with it
    # For now, we'll just simulate this encryption
    # In real app, this would be encrypted with patient's public key
    encrypted_sym_key = sym_key.decode('utf-8')

    # Create record on the blockchain via Go service
    record_data = {
        "patientId": patient_id,
        "hashCID": ipfs_hash,
        "encryptedSymKey": encrypted_sym_key
    }

    response = requests.post(f"{GO_SERVICE_URL}/records", json=record_data)

    if response.status_code != 201:
        return jsonify({"error": "Failed to record on blockchain"}), 500

    record_id = response.json().get('recordId')

    return jsonify({
        "recordId": record_id,
        "hashCID": ipfs_hash,
        "status": "Record uploaded and stored on blockchain"
    }), 201


@app.route('/api/retrieve/<record_id>', methods=['GET'])
def retrieve_record(record_id):
    """
    Retrieve a record from the blockchain and IPFS, decrypt it,
    and return it to the user
    """
    # Get record metadata from blockchain via Go service
    response = requests.get(f"{GO_SERVICE_URL}/records/{record_id}")

    if response.status_code != 200:
        return jsonify({"error": "Failed to retrieve record from blockchain"}), 500

    record = response.json()

    # Get the encrypted file from IPFS
    ipfs_hash = record['hashCID']
    response = requests.get(f"{IPFS_API_URL}/cat?arg={ipfs_hash}")

    if response.status_code != 200:
        return jsonify({"error": "Failed to retrieve file from IPFS"}), 500

    encrypted_file = response.content

    # In a real implementation, this key would be encrypted with the patient's public key
    # and the user would need to use their private key to decrypt it
    # For now, we're just simulating this
    sym_key = record['encryptedSymKey'].encode('utf-8')

    # Decrypt the file
    fernet = Fernet(sym_key)
    decrypted_file = fernet.decrypt(encrypted_file)

    # In a real app, you'd return the decrypted file with appropriate headers
    return jsonify({
        "recordId": record_id,
        "patientId": record['patientId'],
        "fileSize": len(decrypted_file),
        "status": "Record retrieved and decrypted successfully"
    }), 200


@app.route('/api/users', methods=['POST'])
def register_user():
    """
    Register a new user (patient or provider) with the system
    """
    data = request.json

    if not data or 'name' not in data or 'role' not in data:
        return jsonify({"error": "Name and role are required"}), 400

    # Generate a public/private key pair for the user
    # In a real app, this would use asymmetric cryptography
    # For now, just generate a random key for simulation
    random_key = ''.join(random.choices(
        string.ascii_letters + string.digits, k=32))

    user_data = {
        "name": data['name'],
        "role": data['role'],
        "publicKey": random_key
    }

    # Register user on blockchain via Go service
    response = requests.post(f"{GO_SERVICE_URL}/users", json=user_data)

    if response.status_code != 201:
        return jsonify({"error": "Failed to register user on blockchain"}), 500

    user_id = response.json().get('userId')

    return jsonify({
        "userId": user_id,
        "privateKey": random_key,  # In a real app, would return a proper private key
        "status": "User registered successfully"
    }), 201


@app.route('/api/consent', methods=['POST'])
def grant_consent():
    """
    Grant consent to a provider to access a patient's record
    """
    data = request.json

    if not data or 'patientId' not in data or 'recordId' not in data or 'providerId' not in data:
        return jsonify({"error": "Patient ID, Record ID, and Provider ID are required"}), 400

    consent_data = {
        "patientId": data['patientId'],
        "recordId": data['recordId'],
        "providerId": data['providerId'],
        "expiryInDays": data.get('expiryInDays', 30)  # Default to 30 days
    }

    # Grant consent on blockchain via Go service
    response = requests.post(f"{GO_SERVICE_URL}/consent", json=consent_data)

    if response.status_code != 200:
        return jsonify({"error": "Failed to grant consent"}), 500

    return jsonify({
        "status": "Consent granted successfully"
    }), 200


@app.route('/api/consent', methods=['DELETE'])
def revoke_consent():
    """
    Revoke consent from a provider
    """
    data = request.json

    if not data or 'patientId' not in data or 'recordId' not in data or 'providerId' not in data:
        return jsonify({"error": "Patient ID, Record ID, and Provider ID are required"}), 400

    consent_data = {
        "patientId": data['patientId'],
        "recordId": data['recordId'],
        "providerId": data['providerId']
    }

    # Revoke consent on blockchain via Go service
    response = requests.delete(f"{GO_SERVICE_URL}/consent", json=consent_data)

    if response.status_code != 200:
        return jsonify({"error": "Failed to revoke consent"}), 500

    return jsonify({
        "status": "Consent revoked successfully"
    }), 200


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
