package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/hyperledger/fabric-sdk-go/pkg/core/config"
	"github.com/hyperledger/fabric-sdk-go/pkg/gateway"
)

// Record matches the chaincode Record struct
type Record struct {
	RecordID        string `json:"recordId"`
	PatientID       string `json:"patientId"`
	HashCID         string `json:"hashCID"`
	EncryptedSymKey string `json:"encryptedSymKey"`
	Timestamp       string `json:"timestamp"`
}

// UserRequest for registering a new user
type UserRequest struct {
	Name      string `json:"name"`
	Role      string `json:"role"`
	PublicKey string `json:"publicKey"`
}

// RecordRequest for uploading a record
type RecordRequest struct {
	PatientID       string `json:"patientId"`
	HashCID         string `json:"hashCID"`
	EncryptedSymKey string `json:"encryptedSymKey"`
}

// ConsentRequest for granting consent
type ConsentRequest struct {
	PatientID    string `json:"patientId"`
	RecordID     string `json:"recordId"`
	ProviderID   string `json:"providerId"`
	ExpiryInDays int    `json:"expiryInDays"`
}

func main() {
	log.Println("============ MediBlock Go Service Starting ============")

	// Initialize the Gin router
	router := gin.Default()

	// Define API endpoints
	router.POST("/api/users", registerUser)
	router.POST("/api/records", uploadRecord)
	router.GET("/api/records/:recordId", getRecord)
	router.POST("/api/consent", grantConsent)
	router.DELETE("/api/consent", revokeConsent)

	// Start the server
	port := getEnv("PORT", "8081")
	log.Printf("Starting server on port %s", port)
	log.Fatal(router.Run(":" + port))
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}

// Connect to Fabric network
func connectToNetwork() (*gateway.Contract, error) {
	log.Println("Connecting to Fabric network...")

	// Path to crypto materials
	configPath := filepath.Join(
		getEnv("FABRIC_CFG_PATH", "fabric-config"),
		"connection-org1.yaml",
	)

	// Path to user's wallet directory
	walletPath := filepath.Join(
		getEnv("WALLET_PATH", "wallet"),
	)

	// Create the wallet directory if it doesn't exist
	if err := os.MkdirAll(walletPath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create wallet directory: %v", err)
	}

	// Initialize wallet
	wallet, err := gateway.NewFileSystemWallet(walletPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create wallet: %v", err)
	}

	// Create or update the appUser identity in the wallet
	mspID := getEnv("MSP_ID", "Org1MSP")
	certPath := getEnv("USER_CERT_PATH", "")
	keyPath := getEnv("USER_KEY_PATH", "")

	// Only try to create identity if paths are provided
	if certPath != "" && keyPath != "" {
		err = createOrUpdateWalletIdentity(wallet, "appUser", mspID, certPath, keyPath)
		if err != nil {
			log.Printf("Warning: Failed to create/update wallet identity: %v", err)
			// Continue checking if identity exists anyway
		}
	}

	// Check if user identity exists in wallet
	if !wallet.Exists("appUser") {
		return nil, fmt.Errorf("required identity 'appUser' does not exist in wallet")
	}

	// Create a new gateway for connecting to the peer
	gw, err := gateway.Connect(
		gateway.WithConfig(config.FromFile(configPath)),
		gateway.WithIdentity(wallet, "appUser"),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to gateway: %v", err)
	}
	defer gw.Close()

	// Get network (channel) and contract (chaincode)
	channelName := getEnv("CHANNEL_ID", "mychannel")
	network, err := gw.GetNetwork(channelName)
	if err != nil {
		return nil, fmt.Errorf("failed to get network: %v", err)
	}

	chaincodeID := getEnv("CHAINCODE_ID", "ehrmanager")
	contract := network.GetContract(chaincodeID)

	return contract, nil
}

// createOrUpdateWalletIdentity creates or updates a wallet identity
func createOrUpdateWalletIdentity(wallet *gateway.Wallet, label string, mspID string, certPath string, keyPath string) error {
	// Read the certificate file
	certBytes, err := ioutil.ReadFile(certPath)
	if err != nil {
		return fmt.Errorf("failed to read certificate file: %w", err)
	}
	certPEM := string(certBytes)

	// Read the private key file
	keyBytes, err := ioutil.ReadFile(keyPath)
	if err != nil {
		return fmt.Errorf("failed to read private key file: %w", err)
	}
	keyPEM := string(keyBytes)

	// Create a new X.509 identity
	identity := gateway.NewX509Identity(mspID, certPEM, keyPEM)

	// Remove existing identity if it exists
	exists := wallet.Exists(label)
	if exists {
		err = wallet.Remove(label)
		if err != nil {
			return fmt.Errorf("failed to remove existing identity: %w", err)
		}
	}

	// Put the identity in the wallet
	err = wallet.Put(label, identity)
	if err != nil {
		return fmt.Errorf("failed to put identity in wallet: %w", err)
	}

	return nil
}

// API Handlers

func registerUser(c *gin.Context) {
	var request UserRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	contract, err := connectToNetwork()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to connect to network: %v", err)})
		return
	}

	result, err := contract.SubmitTransaction("RegisterUser", request.Name, request.Role, request.PublicKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to register user: %v", err)})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"userId": string(result)})
}

func uploadRecord(c *gin.Context) {
	var request RecordRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	contract, err := connectToNetwork()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to connect to network: %v", err)})
		return
	}

	result, err := contract.SubmitTransaction("UploadRecord", request.PatientID, request.HashCID, request.EncryptedSymKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to upload record: %v", err)})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"recordId": string(result)})
}

func getRecord(c *gin.Context) {
	recordID := c.Param("recordId")

	contract, err := connectToNetwork()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to connect to network: %v", err)})
		return
	}

	result, err := contract.EvaluateTransaction("RetrieveRecord", recordID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to get record: %v", err)})
		return
	}

	var record Record
	err = json.Unmarshal(result, &record)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to parse record: %v", err)})
		return
	}

	c.JSON(http.StatusOK, record)
}

func grantConsent(c *gin.Context) {
	var request ConsentRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	contract, err := connectToNetwork()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to connect to network: %v", err)})
		return
	}

	_, err = contract.SubmitTransaction("GrantConsent", request.PatientID, request.RecordID, request.ProviderID, fmt.Sprintf("%d", request.ExpiryInDays))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to grant consent: %v", err)})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "consent granted"})
}

func revokeConsent(c *gin.Context) {
	var request ConsentRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	contract, err := connectToNetwork()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to connect to network: %v", err)})
		return
	}

	_, err = contract.SubmitTransaction("RevokeConsent", request.PatientID, request.RecordID, request.ProviderID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to revoke consent: %v", err)})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "consent revoked"})
}
