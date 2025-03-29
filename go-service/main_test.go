package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

// MockedResponse represents the JSON response we'll return from our mocked functions
type MockedResponse struct {
	Status string `json:"status"`
	ID     string `json:"id"`
}

// Setup a test router with mocked endpoints
func setupTestRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.Default()

	// Mock endpoints
	r.POST("/api/users", func(c *gin.Context) {
		c.JSON(http.StatusCreated, gin.H{"userId": "test_user_123"})
	})

	r.POST("/api/records", func(c *gin.Context) {
		c.JSON(http.StatusCreated, gin.H{"recordId": "test_record_456"})
	})

	r.GET("/api/records/:recordId", func(c *gin.Context) {
		recordID := c.Param("recordId")
		c.JSON(http.StatusOK, gin.H{
			"recordId":        recordID,
			"patientId":       "test_patient_789",
			"hashCID":         "Qm123456789",
			"encryptedSymKey": "test-key-data",
		})
	})

	r.POST("/api/consent", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "consent granted"})
	})

	r.DELETE("/api/consent", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "consent revoked"})
	})

	return r
}

// Test the user registration endpoint
func TestRegisterUser(t *testing.T) {
	router := setupTestRouter()

	// Create a test request
	reqBody := `{"name":"John Doe","role":"patient","publicKey":"test-key"}`
	req, _ := http.NewRequest("POST", "/api/users", strings.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")

	// Create a response recorder
	w := httptest.NewRecorder()

	// Perform the request
	router.ServeHTTP(w, req)

	// Check the status code
	if w.Code != http.StatusCreated {
		t.Errorf("Expected status code %d, got %d", http.StatusCreated, w.Code)
	}

	// Parse the response
	var response map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Errorf("Error parsing response: %v", err)
	}

	// Check the response fields
	if userId, exists := response["userId"]; !exists || userId != "test_user_123" {
		t.Errorf("Expected userId to be 'test_user_123', got %s", userId)
	}
}

// Test the record upload endpoint
func TestUploadRecord(t *testing.T) {
	router := setupTestRouter()

	// Create a test request
	reqBody := `{"patientId":"test_patient_789","hashCID":"Qm123456789","encryptedSymKey":"test-key-data"}`
	req, _ := http.NewRequest("POST", "/api/records", strings.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")

	// Create a response recorder
	w := httptest.NewRecorder()

	// Perform the request
	router.ServeHTTP(w, req)

	// Check the status code
	if w.Code != http.StatusCreated {
		t.Errorf("Expected status code %d, got %d", http.StatusCreated, w.Code)
	}

	// Parse the response
	var response map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Errorf("Error parsing response: %v", err)
	}

	// Check the response fields
	if recordId, exists := response["recordId"]; !exists || recordId != "test_record_456" {
		t.Errorf("Expected recordId to be 'test_record_456', got %s", recordId)
	}
}

// Test the record retrieval endpoint
func TestGetRecord(t *testing.T) {
	router := setupTestRouter()

	// Create a test request
	req, _ := http.NewRequest("GET", "/api/records/test_record_456", nil)

	// Create a response recorder
	w := httptest.NewRecorder()

	// Perform the request
	router.ServeHTTP(w, req)

	// Check the status code
	if w.Code != http.StatusOK {
		t.Errorf("Expected status code %d, got %d", http.StatusOK, w.Code)
	}

	// Parse the response
	var response map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Errorf("Error parsing response: %v", err)
	}

	// Check the response fields
	if recordId, exists := response["recordId"]; !exists || recordId != "test_record_456" {
		t.Errorf("Expected recordId to be 'test_record_456', got %s", recordId)
	}

	if patientId, exists := response["patientId"]; !exists || patientId != "test_patient_789" {
		t.Errorf("Expected patientId to be 'test_patient_789', got %s", patientId)
	}
}
