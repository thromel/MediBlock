import { useState } from 'react';
import axios from 'axios';
import Head from 'next/head';

// API configuration
const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:5000/api';

export default function Home() {
  // State for user registration
  const [userName, setUserName] = useState('');
  const [userRole, setUserRole] = useState('patient');
  const [userId, setUserId] = useState('');
  const [privateKey, setPrivateKey] = useState('');

  // State for file upload
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [patientId, setPatientId] = useState('');
  const [recordId, setRecordId] = useState('');
  const [uploadSuccess, setUploadSuccess] = useState(false);

  // State for record retrieval
  const [retrieveRecordId, setRetrieveRecordId] = useState('');
  const [retrievedRecord, setRetrievedRecord] = useState<any>(null);

  // User registration
  const registerUser = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const response = await axios.post(`${API_URL}/users`, {
        name: userName,
        role: userRole
      });
      
      setUserId(response.data.userId);
      setPrivateKey(response.data.privateKey);
    } catch (error) {
      console.error('Error registering user:', error);
      alert('Failed to register user');
    }
  };

  // File upload
  const uploadFile = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!selectedFile) {
      alert('Please select a file');
      return;
    }
    
    const formData = new FormData();
    formData.append('file', selectedFile);
    formData.append('patientId', patientId);
    
    try {
      const response = await axios.post(`${API_URL}/upload`, formData);
      
      setRecordId(response.data.recordId);
      setUploadSuccess(true);
    } catch (error) {
      console.error('Error uploading file:', error);
      alert('Failed to upload file');
    }
  };

  // Record retrieval
  const retrieveRecord = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const response = await axios.get(`${API_URL}/retrieve/${retrieveRecordId}`);
      setRetrievedRecord(response.data);
    } catch (error) {
      console.error('Error retrieving record:', error);
      alert('Failed to retrieve record');
    }
  };

  return (
    <div style={{ maxWidth: '800px', margin: '0 auto', padding: '20px' }}>
      <Head>
        <title>MediBlock - Healthcare Blockchain</title>
        <meta name="description" content="MediBlock healthcare blockchain application" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <h1 style={{ textAlign: 'center' }}>MediBlock Healthcare Blockchain</h1>
      
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '40px' }}>
        {/* User Registration */}
        <div style={{ width: '30%', padding: '20px', border: '1px solid #ccc', borderRadius: '5px' }}>
          <h2>Register User</h2>
          <form onSubmit={registerUser}>
            <div style={{ marginBottom: '10px' }}>
              <label htmlFor="userName">Name:</label>
              <input 
                id="userName"
                type="text" 
                value={userName} 
                onChange={(e) => setUserName(e.target.value)} 
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
                required
              />
            </div>
            
            <div style={{ marginBottom: '10px' }}>
              <label htmlFor="userRole">Role:</label>
              <select 
                id="userRole"
                value={userRole} 
                onChange={(e) => setUserRole(e.target.value)}
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
              >
                <option value="patient">Patient</option>
                <option value="provider">Provider</option>
              </select>
            </div>
            
            <button 
              type="submit" 
              style={{ 
                width: '100%', 
                padding: '10px', 
                backgroundColor: '#4CAF50', 
                color: 'white', 
                border: 'none', 
                borderRadius: '4px', 
                cursor: 'pointer'
              }}
            >
              Register
            </button>
          </form>
          
          {userId && (
            <div style={{ marginTop: '20px', padding: '10px', backgroundColor: '#f9f9f9' }}>
              <p><strong>User ID:</strong> {userId}</p>
              <p><strong>Private Key:</strong> {privateKey}</p>
            </div>
          )}
        </div>
        
        {/* File Upload */}
        <div style={{ width: '30%', padding: '20px', border: '1px solid #ccc', borderRadius: '5px' }}>
          <h2>Upload Record</h2>
          <form onSubmit={uploadFile}>
            <div style={{ marginBottom: '10px' }}>
              <label htmlFor="patientId">Patient ID:</label>
              <input 
                id="patientId"
                type="text" 
                value={patientId} 
                onChange={(e) => setPatientId(e.target.value)} 
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
                required
              />
            </div>
            
            <div style={{ marginBottom: '10px' }}>
              <label htmlFor="recordFile">File:</label>
              <input 
                id="recordFile"
                type="file" 
                onChange={(e) => setSelectedFile(e.target.files?.[0] || null)}
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
                required
              />
            </div>
            
            <button 
              type="submit" 
              style={{ 
                width: '100%', 
                padding: '10px', 
                backgroundColor: '#2196F3', 
                color: 'white', 
                border: 'none', 
                borderRadius: '4px', 
                cursor: 'pointer'
              }}
            >
              Upload
            </button>
          </form>
          
          {uploadSuccess && (
            <div style={{ marginTop: '20px', padding: '10px', backgroundColor: '#f9f9f9' }}>
              <p><strong>Record ID:</strong> {recordId}</p>
              <p>✅ Record uploaded successfully</p>
            </div>
          )}
        </div>
        
        {/* Record Retrieval */}
        <div style={{ width: '30%', padding: '20px', border: '1px solid #ccc', borderRadius: '5px' }}>
          <h2>Retrieve Record</h2>
          <form onSubmit={retrieveRecord}>
            <div style={{ marginBottom: '10px' }}>
              <label htmlFor="retrieveRecordId">Record ID:</label>
              <input 
                id="retrieveRecordId"
                type="text" 
                value={retrieveRecordId} 
                onChange={(e) => setRetrieveRecordId(e.target.value)} 
                style={{ width: '100%', padding: '8px', marginTop: '5px' }}
                required
              />
            </div>
            
            <button 
              type="submit" 
              style={{ 
                width: '100%', 
                padding: '10px', 
                backgroundColor: '#9C27B0', 
                color: 'white', 
                border: 'none', 
                borderRadius: '4px', 
                cursor: 'pointer'
              }}
            >
              Retrieve
            </button>
          </form>
          
          {retrievedRecord && (
            <div style={{ marginTop: '20px', padding: '10px', backgroundColor: '#f9f9f9' }}>
              <p><strong>Record ID:</strong> {retrievedRecord.recordId}</p>
              <p><strong>Patient ID:</strong> {retrievedRecord.patientId}</p>
              <p><strong>File Size:</strong> {retrievedRecord.fileSize} bytes</p>
              <p>✅ {retrievedRecord.status}</p>
            </div>
          )}
        </div>
      </div>
      
      <footer style={{ marginTop: '50px', textAlign: 'center', color: '#666' }}>
        <p>MediBlock - A Healthcare Blockchain Solution</p>
      </footer>
    </div>
  );
} 