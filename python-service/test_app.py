import unittest
import json
from unittest.mock import patch, MagicMock
from io import BytesIO
from app import app


class TestPythonService(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_health_check(self):
        """Test the health check endpoint"""
        response = self.app.get('/api/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'healthy')

    @patch('app.requests.post')
    def test_register_user(self, mock_post):
        """Test user registration endpoint"""
        # Mock the response from the Go service
        mock_response = MagicMock()
        mock_response.status_code = 201
        mock_response.json.return_value = {'userId': 'test_user_123'}
        mock_post.return_value = mock_response

        # Test data
        user_data = {
            'name': 'Test User',
            'role': 'patient'
        }

        # Make request to the endpoint
        response = self.app.post(
            '/api/users',
            data=json.dumps(user_data),
            content_type='application/json'
        )

        # Verify response
        self.assertEqual(response.status_code, 201)
        data = json.loads(response.data)
        self.assertEqual(data['userId'], 'test_user_123')
        self.assertIn('privateKey', data)
        self.assertEqual(data['status'], 'User registered successfully')

    @patch('app.requests.post')
    def test_upload_file(self, mock_post):
        """Test file upload endpoint"""
        # Mock responses for IPFS and Go service
        def mock_response_side_effect(*args, **kwargs):
            # First call is to IPFS, second call is to Go service
            if '/add' in args[0]:
                mock_resp = MagicMock()
                mock_resp.status_code = 200
                mock_resp.json.return_value = {'Hash': 'QmTestHash123'}
                return mock_resp
            else:
                mock_resp = MagicMock()
                mock_resp.status_code = 201
                mock_resp.json.return_value = {'recordId': 'record_test_123'}
                return mock_resp

        mock_post.side_effect = mock_response_side_effect

        # Create test file
        test_file = (BytesIO(b'test file content'), 'test_file.txt')

        # Make request to the endpoint
        response = self.app.post(
            '/api/upload',
            data={
                'file': test_file,
                'patientId': 'patient_123'
            },
            content_type='multipart/form-data'
        )

        # Verify response
        self.assertEqual(response.status_code, 201)
        data = json.loads(response.data)
        self.assertEqual(data['recordId'], 'record_test_123')
        self.assertEqual(data['hashCID'], 'QmTestHash123')
        self.assertEqual(
            data['status'], 'Record uploaded and stored on blockchain')

    @patch('app.requests.get')
    def test_retrieve_record(self, mock_get):
        """Test record retrieval endpoint"""
        # Mock responses for blockchain and IPFS
        def mock_response_side_effect(*args, **kwargs):
            if 'records/' in args[0]:
                # Mock blockchain response
                mock_resp = MagicMock()
                mock_resp.status_code = 200
                mock_resp.json.return_value = {
                    'recordId': 'record_test_123',
                    'patientId': 'patient_456',
                    'hashCID': 'QmTestHash123',
                    'encryptedSymKey': 'dGVzdF9rZXk='  # Base64 encoded "test_key"
                }
                return mock_resp
            else:
                # Mock IPFS response
                mock_resp = MagicMock()
                mock_resp.status_code = 200
                mock_resp.content = b'encrypted_content'
                return mock_resp

        mock_get.side_effect = mock_response_side_effect

        # Patch Fernet to return a predictable decryption
        with patch('app.Fernet') as mock_fernet:
            mock_fernet_instance = MagicMock()
            mock_fernet_instance.decrypt.return_value = b'decrypted_file_content'
            mock_fernet.return_value = mock_fernet_instance

            # Make request to the endpoint
            response = self.app.get('/api/retrieve/record_test_123')

            # Verify response
            self.assertEqual(response.status_code, 200)
            data = json.loads(response.data)
            self.assertEqual(data['recordId'], 'record_test_123')
            self.assertEqual(data['patientId'], 'patient_456')
            self.assertEqual(data['fileSize'], len(b'decrypted_file_content'))
            self.assertEqual(
                data['status'], 'Record retrieved and decrypted successfully')

    @patch('app.requests.post')
    def test_grant_consent(self, mock_post):
        """Test consent granting endpoint"""
        # Mock response from Go service
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_post.return_value = mock_response

        # Test data
        consent_data = {
            'patientId': 'patient_123',
            'recordId': 'record_456',
            'providerId': 'provider_789',
            'expiryInDays': 60
        }

        # Make request to the endpoint
        response = self.app.post(
            '/api/consent',
            data=json.dumps(consent_data),
            content_type='application/json'
        )

        # Verify response
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'Consent granted successfully')

    @patch('app.requests.delete')
    def test_revoke_consent(self, mock_delete):
        """Test consent revocation endpoint"""
        # Mock response from Go service
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_delete.return_value = mock_response

        # Test data
        consent_data = {
            'patientId': 'patient_123',
            'recordId': 'record_456',
            'providerId': 'provider_789'
        }

        # Make request to the endpoint
        response = self.app.delete(
            '/api/consent',
            data=json.dumps(consent_data),
            content_type='application/json'
        )

        # Verify response
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'Consent revoked successfully')


if __name__ == '__main__':
    unittest.main()
