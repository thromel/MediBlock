import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import Home from '../pages/index';
import axios from 'axios';

// Mock axios
jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('Home page', () => {
  // Reset mocks before each test
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders the main heading', () => {
    render(<Home />);
    const heading = screen.getByText('MediBlock Healthcare Blockchain');
    expect(heading).toBeInTheDocument();
  });

  it('renders the user registration form', () => {
    render(<Home />);
    expect(screen.getByText('Register User')).toBeInTheDocument();
    expect(screen.getByLabelText('Name:')).toBeInTheDocument();
    expect(screen.getByLabelText('Role:')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Register' })).toBeInTheDocument();
  });

  it('renders the file upload form', () => {
    render(<Home />);
    expect(screen.getByText('Upload Record')).toBeInTheDocument();
    expect(screen.getByLabelText('Patient ID:')).toBeInTheDocument();
    expect(screen.getByLabelText('File:')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Upload' })).toBeInTheDocument();
  });

  it('renders the record retrieval form', () => {
    render(<Home />);
    expect(screen.getByText('Retrieve Record')).toBeInTheDocument();
    expect(screen.getByLabelText('Record ID:')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Retrieve' })).toBeInTheDocument();
  });

  it('should register a user when form is submitted', async () => {
    // Mock the axios response
    mockedAxios.post.mockResolvedValueOnce({
      data: {
        userId: 'test_user_123',
        privateKey: 'test_private_key',
        status: 'User registered successfully'
      }
    });

    render(<Home />);
    
    // Fill in the form
    fireEvent.change(screen.getByLabelText('Name:'), {
      target: { value: 'Test User' }
    });
    
    fireEvent.change(screen.getByLabelText('Role:'), {
      target: { value: 'provider' }
    });
    
    // Submit the form
    fireEvent.click(screen.getByRole('button', { name: 'Register' }));
    
    // Check if axios was called with correct arguments
    expect(mockedAxios.post).toHaveBeenCalledWith(
      expect.stringContaining('/users'),
      {
        name: 'Test User',
        role: 'provider'
      }
    );
    
    // Wait for the response to be rendered
    await waitFor(() => {
      expect(screen.getByText('User ID:')).toBeInTheDocument();
      expect(screen.getByText('test_user_123')).toBeInTheDocument();
      expect(screen.getByText('Private Key:')).toBeInTheDocument();
      expect(screen.getByText('test_private_key')).toBeInTheDocument();
    });
  });

  it('should retrieve a record when form is submitted', async () => {
    // Mock the axios response
    mockedAxios.get.mockResolvedValueOnce({
      data: {
        recordId: 'record_test_123',
        patientId: 'patient_456',
        fileSize: 1024,
        status: 'Record retrieved and decrypted successfully'
      }
    });

    render(<Home />);
    
    // Fill in the form
    fireEvent.change(screen.getByLabelText('Record ID:'), {
      target: { value: 'record_test_123' }
    });
    
    // Submit the form
    fireEvent.click(screen.getByRole('button', { name: 'Retrieve' }));
    
    // Check if axios was called with correct arguments
    expect(mockedAxios.get).toHaveBeenCalledWith(
      expect.stringContaining('/retrieve/record_test_123')
    );
    
    // Wait for the response to be rendered
    await waitFor(() => {
      // Since we have duplicate "Record ID:" text (one in the label, one in the results),
      // we need to make our selectors more specific
      expect(screen.getByText('record_test_123')).toBeInTheDocument();
      expect(screen.getByText('patient_456')).toBeInTheDocument();
      expect(screen.getByText('1024 bytes')).toBeInTheDocument();
      
      // Match status message - need to use a function for this since it's split by emoji
      const statusElement = screen.getByText((content, element) => {
        return element?.textContent === '✅ Record retrieved and decrypted successfully';
      });
      expect(statusElement).toBeInTheDocument();
    });
  });
}); 