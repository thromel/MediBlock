package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// EHRContract for managing health records
type EHRContract struct {
	contractapi.Contract
}

// Record represents a medical record with basic metadata
type Record struct {
	RecordID        string    `json:"recordId"`
	PatientID       string    `json:"patientId"`
	HashCID         string    `json:"hashCID"`
	EncryptedSymKey string    `json:"encryptedSymKey"`
	Timestamp       time.Time `json:"timestamp"`
	DocType         string    `json:"docType"` // Used for CouchDB rich queries
}

// User represents a patient or provider with a public key
type User struct {
	UserID    string `json:"userId"`
	Name      string `json:"name"`
	Role      string `json:"role"` // "patient" or "provider"
	PublicKey string `json:"publicKey"`
	DocType   string `json:"docType"` // Used for CouchDB rich queries
}

// Consent maps a patient-record pair to a list of authorized providers
type Consent struct {
	PatientID   string    `json:"patientId"`
	RecordID    string    `json:"recordId"`
	ProviderIDs []string  `json:"providerIds"`
	ExpiresAt   time.Time `json:"expiresAt,omitempty"`
	DocType     string    `json:"docType"` // Used for CouchDB rich queries
}

// InitLedger initializes the ledger with sample data
func (c *EHRContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	return nil // Nothing to initialize
}

// RegisterUser creates a new user (patient or provider)
func (c *EHRContract) RegisterUser(ctx contractapi.TransactionContextInterface, name string, role string, publicKey string) (string, error) {
	// Generate a unique ID for the user
	uniqueID := fmt.Sprintf("%s_%d", role, time.Now().UnixNano())

	user := User{
		UserID:    uniqueID,
		Name:      name,
		Role:      role,
		PublicKey: publicKey,
		DocType:   "user",
	}

	userJSON, err := json.Marshal(user)
	if err != nil {
		return "", fmt.Errorf("failed to marshal user: %v", err)
	}

	err = ctx.GetStub().PutState(uniqueID, userJSON)
	if err != nil {
		return "", fmt.Errorf("failed to put user on ledger: %v", err)
	}

	return uniqueID, nil
}

// UploadRecord stores a new medical record reference on the chain
func (c *EHRContract) UploadRecord(ctx contractapi.TransactionContextInterface, patientID string, hashCID string, encryptedSymKey string) (string, error) {
	// Verify patient exists
	patientBytes, err := ctx.GetStub().GetState(patientID)
	if err != nil {
		return "", fmt.Errorf("failed to get patient: %v", err)
	}
	if patientBytes == nil {
		return "", fmt.Errorf("patient with ID %s does not exist", patientID)
	}

	// Generate a unique ID for the record
	recordID := fmt.Sprintf("record_%d", time.Now().UnixNano())

	record := Record{
		RecordID:        recordID,
		PatientID:       patientID,
		HashCID:         hashCID,
		EncryptedSymKey: encryptedSymKey,
		Timestamp:       time.Now(),
		DocType:         "record",
	}

	recordJSON, err := json.Marshal(record)
	if err != nil {
		return "", fmt.Errorf("failed to marshal record: %v", err)
	}

	err = ctx.GetStub().PutState(recordID, recordJSON)
	if err != nil {
		return "", fmt.Errorf("failed to put record on ledger: %v", err)
	}

	return recordID, nil
}

// RetrieveRecord gets a record if the caller has consent
func (c *EHRContract) RetrieveRecord(ctx contractapi.TransactionContextInterface, recordID string) (*Record, error) {
	recordBytes, err := ctx.GetStub().GetState(recordID)
	if err != nil {
		return nil, fmt.Errorf("failed to get record: %v", err)
	}
	if recordBytes == nil {
		return nil, fmt.Errorf("record with ID %s does not exist", recordID)
	}

	var record Record
	err = json.Unmarshal(recordBytes, &record)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal record: %v", err)
	}

	// For now, we don't check consent - this will be implemented in Sprint 2

	return &record, nil
}

// GrantConsent allows a patient to give a provider access to a record
func (c *EHRContract) GrantConsent(ctx contractapi.TransactionContextInterface, patientID string, recordID string, providerID string, expiryInDays int) error {
	// Check if consent already exists
	consentKey := fmt.Sprintf("consent_%s_%s", patientID, recordID)
	consentBytes, err := ctx.GetStub().GetState(consentKey)

	var consent Consent

	if err != nil {
		return fmt.Errorf("failed to get consent: %v", err)
	}

	// If consent exists, update it; otherwise, create new consent
	if consentBytes != nil {
		err = json.Unmarshal(consentBytes, &consent)
		if err != nil {
			return fmt.Errorf("failed to unmarshal existing consent: %v", err)
		}

		// Check if provider is already authorized
		for _, pid := range consent.ProviderIDs {
			if pid == providerID {
				return nil // Provider already has consent
			}
		}

		// Add provider to authorized list
		consent.ProviderIDs = append(consent.ProviderIDs, providerID)
	} else {
		// Create new consent
		expiry := time.Time{}
		if expiryInDays > 0 {
			expiry = time.Now().AddDate(0, 0, expiryInDays)
		}

		consent = Consent{
			PatientID:   patientID,
			RecordID:    recordID,
			ProviderIDs: []string{providerID},
			ExpiresAt:   expiry,
			DocType:     "consent",
		}
	}

	consentJSON, err := json.Marshal(consent)
	if err != nil {
		return fmt.Errorf("failed to marshal consent: %v", err)
	}

	err = ctx.GetStub().PutState(consentKey, consentJSON)
	if err != nil {
		return fmt.Errorf("failed to put consent on ledger: %v", err)
	}

	return nil
}

// RevokeConsent removes a provider's access to a record
func (c *EHRContract) RevokeConsent(ctx contractapi.TransactionContextInterface, patientID string, recordID string, providerID string) error {
	consentKey := fmt.Sprintf("consent_%s_%s", patientID, recordID)
	consentBytes, err := ctx.GetStub().GetState(consentKey)

	if err != nil {
		return fmt.Errorf("failed to get consent: %v", err)
	}

	if consentBytes == nil {
		return fmt.Errorf("consent does not exist for patient %s and record %s", patientID, recordID)
	}

	var consent Consent
	err = json.Unmarshal(consentBytes, &consent)
	if err != nil {
		return fmt.Errorf("failed to unmarshal consent: %v", err)
	}

	// Find and remove the provider from the authorized list
	newProviderIDs := make([]string, 0)
	for _, pid := range consent.ProviderIDs {
		if pid != providerID {
			newProviderIDs = append(newProviderIDs, pid)
		}
	}

	// Update the consent
	consent.ProviderIDs = newProviderIDs

	consentJSON, err := json.Marshal(consent)
	if err != nil {
		return fmt.Errorf("failed to marshal updated consent: %v", err)
	}

	err = ctx.GetStub().PutState(consentKey, consentJSON)
	if err != nil {
		return fmt.Errorf("failed to update consent on ledger: %v", err)
	}

	return nil
}

func main() {
	ehrContract := new(EHRContract)

	cc, err := contractapi.NewChaincode(ehrContract)
	if err != nil {
		fmt.Printf("Error creating chaincode: %v\n", err)
		return
	}

	if err := cc.Start(); err != nil {
		fmt.Printf("Error starting chaincode: %v\n", err)
	}
}
