package main

import (
	"encoding/json"
	"testing"
	"time"
)

// Test the Record struct
func TestRecordStruct(t *testing.T) {
	// Create a record
	record := Record{
		RecordID:        "record_123",
		PatientID:       "patient_456",
		HashCID:         "Qm123456789",
		EncryptedSymKey: "encrypted-key-data",
		Timestamp:       time.Now(),
		DocType:         "record",
	}

	// Serialize to JSON
	recordJSON, err := json.Marshal(record)
	if err != nil {
		t.Fatalf("Failed to marshal record: %v", err)
	}

	// Deserialize from JSON
	var deserializedRecord Record
	err = json.Unmarshal(recordJSON, &deserializedRecord)
	if err != nil {
		t.Fatalf("Failed to unmarshal record: %v", err)
	}

	// Validate the fields
	if deserializedRecord.RecordID != "record_123" {
		t.Errorf("Expected record ID to be 'record_123', got '%s'", deserializedRecord.RecordID)
	}
	if deserializedRecord.PatientID != "patient_456" {
		t.Errorf("Expected patient ID to be 'patient_456', got '%s'", deserializedRecord.PatientID)
	}
	if deserializedRecord.HashCID != "Qm123456789" {
		t.Errorf("Expected HashCID to be 'Qm123456789', got '%s'", deserializedRecord.HashCID)
	}
	if deserializedRecord.EncryptedSymKey != "encrypted-key-data" {
		t.Errorf("Expected encrypted key to be 'encrypted-key-data', got '%s'", deserializedRecord.EncryptedSymKey)
	}
	if deserializedRecord.DocType != "record" {
		t.Errorf("Expected DocType to be 'record', got '%s'", deserializedRecord.DocType)
	}
}

// Test the User struct
func TestUserStruct(t *testing.T) {
	// Create a user
	user := User{
		UserID:    "user_123",
		Name:      "John Doe",
		Role:      "patient",
		PublicKey: "public-key-data",
		DocType:   "user",
	}

	// Serialize to JSON
	userJSON, err := json.Marshal(user)
	if err != nil {
		t.Fatalf("Failed to marshal user: %v", err)
	}

	// Deserialize from JSON
	var deserializedUser User
	err = json.Unmarshal(userJSON, &deserializedUser)
	if err != nil {
		t.Fatalf("Failed to unmarshal user: %v", err)
	}

	// Validate the fields
	if deserializedUser.UserID != "user_123" {
		t.Errorf("Expected user ID to be 'user_123', got '%s'", deserializedUser.UserID)
	}
	if deserializedUser.Name != "John Doe" {
		t.Errorf("Expected name to be 'John Doe', got '%s'", deserializedUser.Name)
	}
	if deserializedUser.Role != "patient" {
		t.Errorf("Expected role to be 'patient', got '%s'", deserializedUser.Role)
	}
	if deserializedUser.PublicKey != "public-key-data" {
		t.Errorf("Expected public key to be 'public-key-data', got '%s'", deserializedUser.PublicKey)
	}
	if deserializedUser.DocType != "user" {
		t.Errorf("Expected DocType to be 'user', got '%s'", deserializedUser.DocType)
	}
}

// Test the Consent struct
func TestConsentStruct(t *testing.T) {
	// Create a consent record
	providerIDs := []string{"provider_123", "provider_456"}
	consent := Consent{
		PatientID:   "patient_789",
		RecordID:    "record_123",
		ProviderIDs: providerIDs,
		ExpiresAt:   time.Now().AddDate(0, 0, 30), // Expires in 30 days
		DocType:     "consent",
	}

	// Serialize to JSON
	consentJSON, err := json.Marshal(consent)
	if err != nil {
		t.Fatalf("Failed to marshal consent: %v", err)
	}

	// Deserialize from JSON
	var deserializedConsent Consent
	err = json.Unmarshal(consentJSON, &deserializedConsent)
	if err != nil {
		t.Fatalf("Failed to unmarshal consent: %v", err)
	}

	// Validate the fields
	if deserializedConsent.PatientID != "patient_789" {
		t.Errorf("Expected patient ID to be 'patient_789', got '%s'", deserializedConsent.PatientID)
	}
	if deserializedConsent.RecordID != "record_123" {
		t.Errorf("Expected record ID to be 'record_123', got '%s'", deserializedConsent.RecordID)
	}
	if len(deserializedConsent.ProviderIDs) != 2 {
		t.Errorf("Expected 2 providers, got %d", len(deserializedConsent.ProviderIDs))
	}
	if deserializedConsent.ProviderIDs[0] != "provider_123" {
		t.Errorf("Expected first provider to be 'provider_123', got '%s'", deserializedConsent.ProviderIDs[0])
	}
	if deserializedConsent.ProviderIDs[1] != "provider_456" {
		t.Errorf("Expected second provider to be 'provider_456', got '%s'", deserializedConsent.ProviderIDs[1])
	}
	if deserializedConsent.DocType != "consent" {
		t.Errorf("Expected DocType to be 'consent', got '%s'", deserializedConsent.DocType)
	}
}

// Test consent grant and revoke logic
func TestConsentOperations(t *testing.T) {
	// Create a simple consent
	initialConsent := Consent{
		PatientID:   "patient_123",
		RecordID:    "record_456",
		ProviderIDs: []string{"provider_789"},
		ExpiresAt:   time.Now().AddDate(0, 0, 30),
		DocType:     "consent",
	}

	// Add a provider
	newProviderID := "provider_101112"
	var updatedProviderIDs []string = append(initialConsent.ProviderIDs, newProviderID)

	// Check if provider was added correctly
	if len(updatedProviderIDs) != 2 {
		t.Errorf("Expected 2 providers after adding, got %d", len(updatedProviderIDs))
	}

	if updatedProviderIDs[1] != newProviderID {
		t.Errorf("Expected second provider to be '%s', got '%s'", newProviderID, updatedProviderIDs[1])
	}

	// Remove a provider (simulate revoke)
	var filteredProviderIDs []string
	providerToRemove := "provider_789"

	for _, id := range updatedProviderIDs {
		if id != providerToRemove {
			filteredProviderIDs = append(filteredProviderIDs, id)
		}
	}

	// Check if provider was removed correctly
	if len(filteredProviderIDs) != 1 {
		t.Errorf("Expected 1 provider after removal, got %d", len(filteredProviderIDs))
	}

	if filteredProviderIDs[0] != newProviderID {
		t.Errorf("Expected remaining provider to be '%s', got '%s'", newProviderID, filteredProviderIDs[0])
	}
}

// Test record creation logic
func TestRecordCreation(t *testing.T) {
	patientID := "patient_123"
	hashCID := "QmTestHash123"
	encryptedSymKey := "encrypted-test-sym-key"

	// Basic validation
	if patientID == "" {
		t.Errorf("Patient ID should not be empty")
	}

	if hashCID == "" {
		t.Errorf("Hash CID should not be empty")
	}

	if encryptedSymKey == "" {
		t.Errorf("Encrypted Symmetric Key should not be empty")
	}

	// Create a record
	record := Record{
		RecordID:        "record_test_123",
		PatientID:       patientID,
		HashCID:         hashCID,
		EncryptedSymKey: encryptedSymKey,
		Timestamp:       time.Now(),
		DocType:         "record",
	}

	// Validate record has all required fields
	if record.RecordID == "" {
		t.Errorf("Record ID should not be empty")
	}

	if record.PatientID != patientID {
		t.Errorf("Patient ID mismatch. Expected '%s', got '%s'", patientID, record.PatientID)
	}

	if record.HashCID != hashCID {
		t.Errorf("Hash CID mismatch. Expected '%s', got '%s'", hashCID, record.HashCID)
	}

	if record.EncryptedSymKey != encryptedSymKey {
		t.Errorf("Encrypted Symmetric Key mismatch. Expected '%s', got '%s'",
			encryptedSymKey, record.EncryptedSymKey)
	}

	if record.DocType != "record" {
		t.Errorf("DocType should be 'record', got '%s'", record.DocType)
	}
}

// Test user creation and verification
func TestUserCreationAndVerification(t *testing.T) {
	// Test data for different user roles
	testUsers := []struct {
		name      string
		role      string
		publicKey string
	}{
		{"Alice Smith", "patient", "alice-public-key-123"},
		{"Dr. Bob Johnson", "provider", "bob-public-key-456"},
		{"Hospital Admin", "admin", "admin-public-key-789"},
	}

	// Test creating users with different roles
	for _, testUser := range testUsers {
		// Verify inputs are valid
		if testUser.name == "" {
			t.Errorf("User name should not be empty")
			continue
		}

		if testUser.role == "" {
			t.Errorf("User role should not be empty")
			continue
		}

		if testUser.publicKey == "" {
			t.Errorf("User public key should not be empty")
			continue
		}

		// Create user ID (simulating chaincode logic)
		uniqueID := "user_" + testUser.role + "_" + testUser.name

		// Create the user
		user := User{
			UserID:    uniqueID,
			Name:      testUser.name,
			Role:      testUser.role,
			PublicKey: testUser.publicKey,
			DocType:   "user",
		}

		// Basic verification
		if user.UserID == "" {
			t.Errorf("Generated user ID should not be empty")
		}

		if user.Name != testUser.name {
			t.Errorf("Name mismatch. Expected '%s', got '%s'", testUser.name, user.Name)
		}

		if user.Role != testUser.role {
			t.Errorf("Role mismatch. Expected '%s', got '%s'", testUser.role, user.Role)
		}

		if user.PublicKey != testUser.publicKey {
			t.Errorf("Public key mismatch. Expected '%s', got '%s'",
				testUser.publicKey, user.PublicKey)
		}

		if user.DocType != "user" {
			t.Errorf("DocType should be 'user', got '%s'", user.DocType)
		}

		// Test serialization and deserialization
		userJSON, err := json.Marshal(user)
		if err != nil {
			t.Fatalf("Failed to marshal user: %v", err)
		}

		var deserializedUser User
		err = json.Unmarshal(userJSON, &deserializedUser)
		if err != nil {
			t.Fatalf("Failed to unmarshal user: %v", err)
		}

		// Verify deserialized user matches original
		if deserializedUser.UserID != user.UserID {
			t.Errorf("UserID mismatch after serialization. Expected '%s', got '%s'",
				user.UserID, deserializedUser.UserID)
		}

		if deserializedUser.Role != user.Role {
			t.Errorf("Role mismatch after serialization. Expected '%s', got '%s'",
				user.Role, deserializedUser.Role)
		}
	}
}
