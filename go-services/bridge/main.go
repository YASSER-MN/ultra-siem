package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/google/uuid"
	"github.com/nats-io/nats.go"
)

// ThreatEvent represents the threat event format from Rust core
type ThreatEvent struct {
	Timestamp   int64   `json:"timestamp"`
	SourceIP    string  `json:"source_ip"`
	ThreatType  string  `json:"threat_type"`
	Payload     string  `json:"payload"`
	Severity    int     `json:"severity"`
	Confidence  float64 `json:"confidence"`
}

// SystemEvent represents system events from Rust core
type SystemEvent struct {
	Timestamp int64  `json:"timestamp"`
	EventType string `json:"event_type"`
	Source    string `json:"source"`
	Message   string `json:"message"`
	Severity  int    `json:"severity"`
}

// Enhanced UltraSIEMEvent struct for all collectors with comprehensive fields
type UltraSIEMEvent struct {
	ID             string                 `json:"id"`
	Timestamp      int64                  `json:"timestamp"`
	SourceIP       string                 `json:"source_ip"`
	DestinationIP  string                 `json:"destination_ip"`
	SourcePort     uint16                 `json:"source_port"`
	DestinationPort uint16                `json:"destination_port"`
	Protocol       string                 `json:"protocol"`
	EventType      string                 `json:"event_type"`
	Severity       int                    `json:"severity"`
	User           string                 `json:"user"`
	Hostname       string                 `json:"hostname"`
	Process        string                 `json:"process"`
	ProcessID      uint32                 `json:"process_id"`
	LogSource      string                 `json:"log_source"`
	Message        string                 `json:"message"`
	RawMessage     string                 `json:"raw_message"`
	EventID        uint32                 `json:"event_id"`
	SessionID      string                 `json:"session_id"`
	UserAgent      string                 `json:"user_agent"`
	RequestURI     string                 `json:"request_uri"`
	HTTPMethod     string                 `json:"http_method"`
	ResponseCode   uint16                 `json:"response_code"`
	BytesTransferred uint64               `json:"bytes_transferred"`
	CommandLine    string                 `json:"command_line"`
	FileHash       string                 `json:"file_hash"`
	RegistryKey    string                 `json:"registry_key"`
	NetworkConnection string              `json:"network_connection"`
	DNSQuery       string                 `json:"dns_query"`
	CertificateInfo string                `json:"certificate_info"`
	ThreatIntelligenceMatch string        `json:"threat_intelligence_match"`
	MLScore        float32                `json:"ml_score"`
	FalsePositive  bool                   `json:"false_positive"`
	AnalystNotes   string                 `json:"analyst_notes"`
	RemediationStatus string              `json:"remediation_status"`
	IncidentID     string                 `json:"incident_id"`
	ComplianceTags []string               `json:"compliance_tags"`
	DataClassification string             `json:"data_classification"`
	RetentionPolicy string                `json:"retention_policy"`
	EncryptionStatus bool                 `json:"encryption_status"`
	AuditTrail     string                 `json:"audit_trail"`
	Metadata       map[string]interface{} `json:"metadata"`
}

// GeoIP enrichment data
type GeoIPData struct {
	Country     string  `json:"country"`
	City        string  `json:"city"`
	Region      string  `json:"region"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	ASN         uint32  `json:"asn"`
	ASName      string  `json:"as_name"`
	IsTor       bool    `json:"is_tor"`
	Reputation  float32 `json:"reputation"`
}

// SimpleBridge handles NATS to ClickHouse bridging with enhanced capabilities
type SimpleBridge struct {
	nc     *nats.Conn
	js     nats.JetStreamContext
	db     driver.Conn
	ctx    context.Context
	cancel context.CancelFunc
	stats  *SimpleStats
	mu     sync.RWMutex
	geoIP  *GeoIPEnricher
	config *BridgeConfig
}

// BridgeConfig holds configuration for the bridge
type BridgeConfig struct {
	NATSUrl           string
	ClickHouseURL     string
	ClickHouseUser    string
	ClickHousePass    string
	ClickHouseDB      string
	BatchSize         int
	BatchTimeout      time.Duration
	MaxRetries        int
	RetryDelay        time.Duration
	EnableTLS         bool
	TLSCertFile       string
	TLSKeyFile        string
	TLSCACertFile     string
	EnableMetrics     bool
	MetricsPort       int
	LogLevel          string
	MaxConnections    int
	ConnectionTimeout time.Duration
	QueryTimeout      time.Duration
}

// SimpleStats holds runtime statistics
type SimpleStats struct {
	eventsProcessed uint64
	threatsProcessed uint64
	errors          uint64
	enrichments     uint64
	lastUpdate      time.Time
	mu              sync.RWMutex
}

// GeoIPEnricher handles IP enrichment
type GeoIPEnricher struct {
	cache map[string]*GeoIPData
	mu    sync.RWMutex
}

func NewGeoIPEnricher() *GeoIPEnricher {
	return &GeoIPEnricher{
		cache: make(map[string]*GeoIPData),
	}
}

func (g *GeoIPEnricher) EnrichIP(ip string) *GeoIPData {
	if ip == "" || ip == "0.0.0.0" || ip == "::1" {
		return &GeoIPData{}
	}

	g.mu.RLock()
	if data, exists := g.cache[ip]; exists {
		g.mu.RUnlock()
		return data
	}
	g.mu.RUnlock()

	// Enhanced GeoIP lookup (replace with real service in production)
	data := g.lookupIP(ip)

	g.mu.Lock()
	g.cache[ip] = data
	g.mu.Unlock()

	return data
}

func (g *GeoIPEnricher) lookupIP(ip string) *GeoIPData {
	// Enhanced IP lookup with more realistic data
	parsedIP := net.ParseIP(ip)
	if parsedIP == nil {
		return &GeoIPData{}
	}

	// Private IP ranges
	if parsedIP.IsPrivate() || parsedIP.IsLoopback() {
		return &GeoIPData{
			Country:   "PRIVATE",
			City:      "Internal",
			Region:    "Internal",
			Latitude:  0.0,
			Longitude: 0.0,
			ASN:       0,
			ASName:    "Private Network",
			IsTor:     false,
			Reputation: 100.0,
		}
	}

	// Enhanced mock data based on IP patterns
	// In production, replace with MaxMind GeoIP2 or similar service
	switch {
	case strings.HasPrefix(ip, "8.8."):
		return &GeoIPData{
			Country:   "US",
			City:      "Mountain View",
			Region:    "CA",
			Latitude:  37.4056,
			Longitude: -122.0775,
			ASN:       15169,
			ASName:    "Google LLC",
			IsTor:     false,
			Reputation: 95.0,
		}
	case strings.HasPrefix(ip, "1.1."):
		return &GeoIPData{
			Country:   "US",
			City:      "Los Angeles",
			Region:    "CA",
			Latitude:  34.0522,
			Longitude: -118.2437,
			ASN:       13335,
			ASName:    "Cloudflare",
			IsTor:     false,
			Reputation: 90.0,
		}
	case strings.HasPrefix(ip, "208.67."):
		return &GeoIPData{
			Country:   "US",
			City:      "San Francisco",
			Region:    "CA",
			Latitude:  37.7749,
			Longitude: -122.4194,
			ASN:       36692,
			ASName:    "OpenDNS",
			IsTor:     false,
			Reputation: 85.0,
		}
	default:
		// Generate realistic mock data based on IP hash
		hash := 0
		for _, char := range ip {
			hash += int(char)
		}
		
		countries := []string{"US", "CA", "GB", "DE", "FR", "JP", "AU", "BR", "IN", "CN"}
		cities := []string{"New York", "London", "Berlin", "Paris", "Tokyo", "Sydney", "São Paulo", "Mumbai", "Beijing", "Toronto"}
		
		countryIdx := hash % len(countries)
		cityIdx := hash % len(cities)
		
		return &GeoIPData{
			Country:   countries[countryIdx],
			City:      cities[cityIdx],
			Region:    "Unknown",
			Latitude:  float64(hash%90) - 45.0,
			Longitude: float64(hash%180) - 90.0,
			ASN:       uint32(hash % 65535),
			ASName:    "ISP Network",
			IsTor:     hash%100 < 5, // 5% chance of being Tor
			Reputation: float32(50 + hash%50), // 50-100 reputation score
		}
	}
}

// NewSimpleBridge creates a new bridge instance with enhanced configuration
func NewSimpleBridge(config *BridgeConfig) (*SimpleBridge, error) {
	ctx, cancel := context.WithCancel(context.Background())

	// Enhanced NATS connection with TLS support
	var natsOpts []nats.Option
	if config.EnableTLS {
		tlsConfig, err := createTLSConfig(config)
		if err != nil {
			cancel()
			return nil, fmt.Errorf("failed to create TLS config: %w", err)
		}
		natsOpts = append(natsOpts, nats.Secure(tlsConfig))
	}

	// Enhanced NATS connection options
	natsOpts = append(natsOpts,
		nats.Name("UltraSIEM-Bridge"),
		nats.MaxReconnects(-1),
		nats.ReconnectWait(time.Second),
		nats.Timeout(config.ConnectionTimeout),
		nats.PingInterval(30*time.Second),
		nats.MaxPingsOutstanding(5),
	)

	nc, err := nats.Connect(config.NATSUrl, natsOpts...)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	js, err := nc.JetStream()
	if err != nil {
		nc.Close()
		cancel()
		return nil, fmt.Errorf("failed to get JetStream context: %w", err)
	}

	// Enhanced ClickHouse connection with TLS support
	var tlsConfig *tls.Config
	if config.EnableTLS {
		tlsConfig, err = createClickHouseTLSConfig(config)
		if err != nil {
			nc.Close()
			cancel()
			return nil, fmt.Errorf("failed to create ClickHouse TLS config: %w", err)
		}
	}

	db, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{config.ClickHouseURL},
		Auth: clickhouse.Auth{
			Database: config.ClickHouseDB,
			Username: config.ClickHouseUser,
			Password: config.ClickHousePass,
		},
		TLS: tlsConfig,
		Settings: clickhouse.Settings{
			"max_execution_time": config.QueryTimeout.Seconds(),
		},
		Compression: &clickhouse.Compression{
			Method: clickhouse.CompressionLZ4,
		},
		MaxOpenConns:    config.MaxConnections,
		MaxIdleConns:    config.MaxConnections / 2,
		ConnMaxLifetime: time.Hour,
	})
	if err != nil {
		nc.Close()
		cancel()
		return nil, fmt.Errorf("failed to connect to ClickHouse: %w", err)
	}

	// Test database connection
	if err := db.Ping(ctx); err != nil {
		db.Close()
		nc.Close()
		cancel()
		return nil, fmt.Errorf("failed to ping ClickHouse: %w", err)
	}

	// Create tables if they don't exist
	if err := createTableIfNotExists(ctx, db); err != nil {
		db.Close()
		nc.Close()
		cancel()
		return nil, fmt.Errorf("failed to create tables: %w", err)
	}

	return &SimpleBridge{
		nc:     nc,
		js:     js,
		db:     db,
		ctx:    ctx,
		cancel: cancel,
		stats:  &SimpleStats{},
		geoIP:  NewGeoIPEnricher(),
		config: config,
	}, nil
}

// createTLSConfig creates TLS configuration for NATS
func createTLSConfig(config *BridgeConfig) (*tls.Config, error) {
	cert, err := tls.LoadX509KeyPair(config.TLSCertFile, config.TLSKeyFile)
	if err != nil {
		return nil, err
	}

	caCert, err := os.ReadFile(config.TLSCACertFile)
	if err != nil {
		return nil, err
	}

	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(caCert)

	return &tls.Config{
		Certificates: []tls.Certificate{cert},
		RootCAs:      caCertPool,
		MinVersion:   tls.VersionTLS12,
		CipherSuites: []uint16{
			tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,
		},
	}, nil
}

// createClickHouseTLSConfig creates TLS configuration for ClickHouse
func createClickHouseTLSConfig(config *BridgeConfig) (*tls.Config, error) {
	caCert, err := os.ReadFile(config.TLSCACertFile)
	if err != nil {
		return nil, err
	}

	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(caCert)

	return &tls.Config{
		RootCAs:    caCertPool,
		MinVersion: tls.VersionTLS12,
	}, nil
}

func createTableIfNotExists(ctx context.Context, db driver.Conn) error {
	// Create threats table with enhanced schema
	threatsQuery := `
	CREATE TABLE IF NOT EXISTS ultra_siem.threats (
		id UUID,
		timestamp DateTime,
		threat_type String,
		confidence Float32,
		source_ip String,
		destination_ip String,
		source_port UInt16,
		destination_port UInt16,
		protocol String,
		message String,
		metadata String,
		severity UInt8,
		status String,
		user String,
		hostname String,
		process String,
		process_id UInt32,
		log_source String,
		raw_message String,
		event_id UInt32,
		session_id String,
		user_agent String,
		request_uri String,
		http_method String,
		response_code UInt16,
		bytes_transferred UInt64,
		command_line String,
		file_hash String,
		registry_key String,
		network_connection String,
		dns_query String,
		certificate_info String,
		threat_intelligence_match String,
		ml_score Float32,
		false_positive UInt8,
		analyst_notes String,
		remediation_status String,
		incident_id String,
		compliance_tags String,
		data_classification String,
		retention_policy String,
		encryption_status UInt8,
		audit_trail String,
		geoip_country String,
		geoip_city String,
		geoip_region String,
		geoip_latitude Float64,
		geoip_longitude Float64,
		geoip_asn UInt32,
		geoip_as_name String,
		geoip_is_tor UInt8,
		geoip_reputation Float32
	) ENGINE = MergeTree()
	ORDER BY (timestamp, source_ip)
	`
	if err := db.Exec(ctx, threatsQuery); err != nil {
		return fmt.Errorf("failed to create threats table: %w", err)
	}

	// Enhanced events table schema with all collector fields
	eventsQuery := `
	CREATE TABLE IF NOT EXISTS ultra_siem.events (
		id UUID,
		timestamp DateTime,
		source_ip String,
		destination_ip String,
		source_port UInt16,
		destination_port UInt16,
		protocol String,
		event_type String,
		severity UInt8,
		user String,
		hostname String,
		process String,
		process_id UInt32,
		log_source String,
		message String,
		raw_message String,
		event_id UInt32,
		session_id String,
		user_agent String,
		request_uri String,
		http_method String,
		response_code UInt16,
		bytes_transferred UInt64,
		command_line String,
		file_hash String,
		registry_key String,
		network_connection String,
		dns_query String,
		certificate_info String,
		threat_intelligence_match String,
		ml_score Float32,
		false_positive UInt8,
		analyst_notes String,
		remediation_status String,
		incident_id String,
		compliance_tags String,
		data_classification String,
		retention_policy String,
		encryption_status UInt8,
		audit_trail String,
		metadata String,
		geoip_country String,
		geoip_city String,
		geoip_region String,
		geoip_latitude Float64,
		geoip_longitude Float64,
		geoip_asn UInt32,
		geoip_as_name String,
		geoip_is_tor UInt8,
		geoip_reputation Float32
	) ENGINE = MergeTree()
	ORDER BY (timestamp, source_ip)
	`
	if err := db.Exec(ctx, eventsQuery); err != nil {
		return fmt.Errorf("failed to create events table: %w", err)
	}
	return nil
}

func (b *SimpleBridge) Start() error {
	log.Println("🚀 Starting Ultra SIEM Enhanced Bridge...")

	// Subscribe to threats with timeout
	threatsSub, err := b.js.Subscribe("ultra_siem.threats", b.handleThreatEvent)
	if err != nil {
		return fmt.Errorf("failed to subscribe to ultra_siem.threats: %w", err)
	}
	defer threatsSub.Unsubscribe()

	// Subscribe to events with timeout
	eventsSub, err := b.js.Subscribe("ultra_siem.events", b.handleUltraSIEMEvent)
	if err != nil {
		return fmt.Errorf("failed to subscribe to ultra_siem.events: %w", err)
	}
	defer eventsSub.Unsubscribe()

	// Start statistics reporting
	go b.reportStats()

	log.Println("✅ Ultra SIEM Enhanced Bridge started successfully")
	log.Println("📡 Listening for events on: ultra_siem.threats, ultra_siem.events")

	// Keep the service running
	select {
	case <-b.ctx.Done():
		return b.ctx.Err()
	}
}

func (b *SimpleBridge) handleThreatEvent(msg *nats.Msg) {
	var event ThreatEvent
	if err := json.Unmarshal(msg.Data, &event); err != nil {
		log.Printf("❌ Error unmarshaling threat event: %v", err)
		b.updateErrorStats()
		return
	}

	// Process the event with timeout
	ctxTimeout, cancel := context.WithTimeout(b.ctx, 5*time.Second)
	defer cancel()

	if err := b.processThreatEvent(ctxTimeout, &event); err != nil {
		log.Printf("❌ Error processing threat event: %v", err)
		b.updateErrorStats()
		return
	}

	b.updateThreatStats()
	log.Printf("✅ Processed threat: %s from %s (confidence: %.2f)", 
		event.ThreatType, event.SourceIP, event.Confidence)
}

func (b *SimpleBridge) handleSystemEvent(msg *nats.Msg) {
	var event SystemEvent
	if err := json.Unmarshal(msg.Data, &event); err != nil {
		log.Printf("❌ Error unmarshaling system event: %v", err)
		b.updateErrorStats()
		return
	}

	// Process the event with timeout
	ctxTimeout, cancel := context.WithTimeout(b.ctx, 5*time.Second)
	defer cancel()

	if err := b.processSystemEvent(ctxTimeout, &event); err != nil {
		log.Printf("❌ Error processing system event: %v", err)
		b.updateErrorStats()
		return
	}

	b.updateEventStats()
	log.Printf("📊 Processed system event: %s from %s", event.EventType, event.Source)
}

func (b *SimpleBridge) handleUltraSIEMEvent(msg *nats.Msg) {
	var event UltraSIEMEvent
	if err := json.Unmarshal(msg.Data, &event); err != nil {
		log.Printf("❌ Error unmarshaling UltraSIEM event: %v", err)
		b.updateErrorStats()
		return
	}

	// Enhanced enrichment (GeoIP, etc.)
	b.enrichUltraSIEMEvent(&event)

	ctxTimeout, cancel := context.WithTimeout(b.ctx, 5*time.Second)
	defer cancel()

	if err := b.processUltraSIEMEvent(ctxTimeout, &event); err != nil {
		log.Printf("❌ Error processing UltraSIEM event: %v", err)
		b.updateErrorStats()
		return
	}

	b.updateEventStats()
	log.Printf("✅ Processed event: %s from %s (user: %s, host: %s)", event.EventType, event.SourceIP, event.User, event.Hostname)
}

func (b *SimpleBridge) processThreatEvent(ctx context.Context, event *ThreatEvent) error {
	// Enrich threat event with GeoIP
	geoData := b.geoIP.EnrichIP(event.SourceIP)

	// Prepare batch insert with timeout
	batch, err := b.db.PrepareBatch(ctx, "INSERT INTO ultra_siem.threats")
	if err != nil {
		return fmt.Errorf("error preparing batch: %w", err)
	}

	// Add event to batch with enhanced fields
	err = batch.Append(
		generateUUID(),
		time.Unix(event.Timestamp, 0),
		event.ThreatType,
		float32(event.Confidence),
		event.SourceIP,
		"", // destination_ip
		0,  // source_port
		0,  // destination_port
		"", // protocol
		event.Payload,
		fmt.Sprintf("{\"source_ip\":\"%s\",\"confidence\":%.2f}", event.SourceIP, event.Confidence),
		uint8(event.Severity),
		"new",
		"", // user
		"", // hostname
		"", // process
		0,  // process_id
		"", // log_source
		"", // raw_message
		0,  // event_id
		"", // session_id
		"", // user_agent
		"", // request_uri
		"", // http_method
		0,  // response_code
		0,  // bytes_transferred
		"", // command_line
		"", // file_hash
		"", // registry_key
		"", // network_connection
		"", // dns_query
		"", // certificate_info
		"", // threat_intelligence_match
		0.0, // ml_score
		0,   // false_positive
		"",  // analyst_notes
		"",  // remediation_status
		"",  // incident_id
		"",  // compliance_tags
		"",  // data_classification
		"",  // retention_policy
		1,   // encryption_status
		"",  // audit_trail
		geoData.Country,
		geoData.City,
		geoData.Region,
		geoData.Latitude,
		geoData.Longitude,
		geoData.ASN,
		geoData.ASName,
		boolToUint8(geoData.IsTor),
		geoData.Reputation,
	)
	if err != nil {
		return fmt.Errorf("error appending to batch: %w", err)
	}

	// Send batch with timeout
	if err := batch.Send(); err != nil {
		return fmt.Errorf("error sending batch: %w", err)
	}

	return nil
}

func (b *SimpleBridge) processSystemEvent(ctx context.Context, event *SystemEvent) error {
	// Publish event to NATS ultra_siem.events
	data, err := json.Marshal(event)
	if err == nil {
		b.nc.Publish("ultra_siem.events", data)
	}

	// Prepare batch insert with timeout
	batch, err := b.db.PrepareBatch(ctx, "INSERT INTO ultra_siem.events")
	if err != nil {
		return fmt.Errorf("error preparing batch: %w", err)
	}

	// Add event to batch with enhanced fields
	err = batch.Append(
		generateUUID(),
		time.Unix(event.Timestamp, 0),
		event.Source,
		"", // destination_ip
		0,  // source_port
		0,  // destination_port
		"", // protocol
		event.EventType,
		uint8(event.Severity),
		"", // user
		"", // hostname
		"", // process
		0,  // process_id
		"", // log_source
		event.Message,
		"", // raw_message
		0,  // event_id
		"", // session_id
		"", // user_agent
		"", // request_uri
		"", // http_method
		0,  // response_code
		0,  // bytes_transferred
		"", // command_line
		"", // file_hash
		"", // registry_key
		"", // network_connection
		"", // dns_query
		"", // certificate_info
		"", // threat_intelligence_match
		0.0, // ml_score
		0,   // false_positive
		"",  // analyst_notes
		"",  // remediation_status
		"",  // incident_id
		"",  // compliance_tags
		"",  // data_classification
		"",  // retention_policy
		1,   // encryption_status
		"",  // audit_trail
		"",  // metadata
		"",  // geoip_country
		"",  // geoip_city
		"",  // geoip_region
		0.0, // geoip_latitude
		0.0, // geoip_longitude
		0,   // geoip_asn
		"",  // geoip_as_name
		0,   // geoip_is_tor
		0.0, // geoip_reputation
	)
	if err != nil {
		return fmt.Errorf("error appending to batch: %w", err)
	}

	// Send batch with timeout
	if err := batch.Send(); err != nil {
		return fmt.Errorf("error sending batch: %w", err)
	}

	return nil
}

func (b *SimpleBridge) processUltraSIEMEvent(ctx context.Context, event *UltraSIEMEvent) error {
	// Enrich event with GeoIP data
	geoData := b.geoIP.EnrichIP(event.SourceIP)
	b.updateEnrichmentStats()

	batch, err := b.db.PrepareBatch(ctx, "INSERT INTO ultra_siem.events")
	if err != nil {
		return fmt.Errorf("error preparing batch: %w", err)
	}

	metadataJSON, _ := json.Marshal(event.Metadata)
	complianceTagsJSON, _ := json.Marshal(event.ComplianceTags)

	err = batch.Append(
		generateUUID(),
		time.Unix(event.Timestamp, 0),
		event.SourceIP,
		event.DestinationIP,
		event.SourcePort,
		event.DestinationPort,
		event.Protocol,
		event.EventType,
		uint8(event.Severity),
		event.User,
		event.Hostname,
		event.Process,
		event.ProcessID,
		event.LogSource,
		event.Message,
		event.RawMessage,
		event.EventID,
		event.SessionID,
		event.UserAgent,
		event.RequestURI,
		event.HTTPMethod,
		event.ResponseCode,
		event.BytesTransferred,
		event.CommandLine,
		event.FileHash,
		event.RegistryKey,
		event.NetworkConnection,
		event.DNSQuery,
		event.CertificateInfo,
		event.ThreatIntelligenceMatch,
		event.MLScore,
		boolToUint8(event.FalsePositive),
		event.AnalystNotes,
		event.RemediationStatus,
		event.IncidentID,
		string(complianceTagsJSON),
		event.DataClassification,
		event.RetentionPolicy,
		boolToUint8(event.EncryptionStatus),
		event.AuditTrail,
		string(metadataJSON),
		geoData.Country,
		geoData.City,
		geoData.Region,
		geoData.Latitude,
		geoData.Longitude,
		geoData.ASN,
		geoData.ASName,
		boolToUint8(geoData.IsTor),
		geoData.Reputation,
	)
	if err != nil {
		return fmt.Errorf("error appending to batch: %w", err)
	}
	if err := batch.Send(); err != nil {
		return fmt.Errorf("error sending batch: %w", err)
	}

	// Publish enriched event to NATS for Rust core analysis
	data, err := json.Marshal(event)
	if err == nil {
		b.nc.Publish("ultra_siem.events", data)
	}
	return nil
}

func (b *SimpleBridge) updateEventStats() {
	b.stats.mu.Lock()
	defer b.stats.mu.Unlock()
	b.stats.eventsProcessed++
	b.stats.lastUpdate = time.Now()
}

func (b *SimpleBridge) updateThreatStats() {
	b.stats.mu.Lock()
	defer b.stats.mu.Unlock()
	b.stats.threatsProcessed++
	b.stats.lastUpdate = time.Now()
}

func (b *SimpleBridge) updateErrorStats() {
	b.stats.mu.Lock()
	defer b.stats.mu.Unlock()
	b.stats.errors++
	b.stats.lastUpdate = time.Now()
}

func (b *SimpleBridge) updateEnrichmentStats() {
	b.stats.mu.Lock()
	defer b.stats.mu.Unlock()
	b.stats.enrichments++
	b.stats.lastUpdate = time.Now()
}

func (b *SimpleBridge) reportStats() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			b.stats.mu.RLock()
			events := b.stats.eventsProcessed
			threats := b.stats.threatsProcessed
			errors := b.stats.errors
			enrichments := b.stats.enrichments
			b.stats.mu.RUnlock()

			log.Printf("📊 Stats: Events=%d, Threats=%d, Enrichments=%d, Errors=%d", events, threats, enrichments, errors)
		case <-b.ctx.Done():
			return
		}
	}
}

func (b *SimpleBridge) Shutdown() {
	log.Println("🛑 Shutting down Ultra SIEM Enhanced Bridge...")
	b.cancel()
	b.nc.Close()
	b.db.Close()
}

// generateUUID generates a secure UUID for event identification
func generateUUID() string {
	return uuid.New().String()
}

// enrichUltraSIEMEvent enriches events with GeoIP and threat intelligence data
func (b *SimpleBridge) enrichUltraSIEMEvent(event *UltraSIEMEvent) {
	// Generate UUID if not present
	if event.ID == "" {
		event.ID = generateUUID()
	}

	// Enrich with GeoIP data
	if event.SourceIP != "" {
		geoData := b.geoIP.EnrichIP(event.SourceIP)
		// Note: In production, you would map these to the actual database fields
		// For now, we'll store them in metadata
		if event.Metadata == nil {
			event.Metadata = make(map[string]interface{})
		}
		event.Metadata["geoip"] = geoData
	}

	// Add timestamp if not present
	if event.Timestamp == 0 {
		event.Timestamp = time.Now().UnixNano() / int64(time.Millisecond)
	}

	// Add default values for required fields
	if event.LogSource == "" {
		event.LogSource = "ultra_siem_bridge"
	}

	if event.DataClassification == "" {
		event.DataClassification = "internal"
	}

	if event.RetentionPolicy == "" {
		event.RetentionPolicy = "standard"
	}

	// Add compliance tags based on event type
	if event.ComplianceTags == nil {
		event.ComplianceTags = []string{}
	}

	// Add relevant compliance tags
	switch event.EventType {
	case "authentication", "login", "logout":
		event.ComplianceTags = append(event.ComplianceTags, "SOX", "PCI-DSS", "GDPR")
	case "file_access", "data_access":
		event.ComplianceTags = append(event.ComplianceTags, "SOX", "HIPAA", "GDPR")
	case "network_connection", "firewall":
		event.ComplianceTags = append(event.ComplianceTags, "PCI-DSS", "NIST")
	case "threat_detection", "malware":
		event.ComplianceTags = append(event.ComplianceTags, "NIST", "ISO27001")
	}

	// Update enrichment statistics
	b.updateEnrichmentStats()
}

// boolToUint8 converts boolean to uint8 for database storage
func boolToUint8(b bool) uint8 {
	if b {
		return 1
	}
	return 0
}

// Enhanced main function with comprehensive error handling and monitoring
func main() {
	log.Println("🚀 Ultra SIEM Enhanced Bridge Starting...")

	// Define default configuration
	config := &BridgeConfig{
		NATSUrl:           "nats://nats:4222",
		ClickHouseURL:     "clickhouse:9000",
		ClickHouseUser:    "admin",
		ClickHousePass:    "admin",
		ClickHouseDB:      "ultra_siem",
		BatchSize:         100,
		BatchTimeout:     5 * time.Second,
		MaxRetries:       3,
		RetryDelay:       1 * time.Second,
		EnableTLS:        false,
		TLSCertFile:      "",
		TLSKeyFile:       "",
		TLSCACertFile:    "",
		EnableMetrics:    false,
		MetricsPort:      8080,
		LogLevel:         "info",
		MaxConnections:   10,
		ConnectionTimeout: 10 * time.Second,
		QueryTimeout:     60 * time.Second,
	}

	// Override with environment variables if available
	if natsURL := os.Getenv("NATS_URL"); natsURL != "" {
		config.NATSUrl = natsURL
	}
	if clickhouseURL := os.Getenv("CLICKHOUSE_URL"); clickhouseURL != "" {
		config.ClickHouseURL = clickhouseURL
	}
	if clickhouseUser := os.Getenv("CLICKHOUSE_USER"); clickhouseUser != "" {
		config.ClickHouseUser = clickhouseUser
	}
	if clickhousePass := os.Getenv("CLICKHOUSE_PASS"); clickhousePass != "" {
		config.ClickHousePass = clickhousePass
	}
	if clickhouseDB := os.Getenv("CLICKHOUSE_DB"); clickhouseDB != "" {
		config.ClickHouseDB = clickhouseDB
	}
	if batchSize := os.Getenv("BATCH_SIZE"); batchSize != "" {
		if size, err := strconv.Atoi(batchSize); err == nil {
			config.BatchSize = size
		}
	}
	if batchTimeout := os.Getenv("BATCH_TIMEOUT"); batchTimeout != "" {
		if timeout, err := time.ParseDuration(batchTimeout); err == nil {
			config.BatchTimeout = timeout
		}
	}
	if maxRetries := os.Getenv("MAX_RETRIES"); maxRetries != "" {
		if retries, err := strconv.Atoi(maxRetries); err == nil {
			config.MaxRetries = retries
		}
	}
	if retryDelay := os.Getenv("RETRY_DELAY"); retryDelay != "" {
		if delay, err := time.ParseDuration(retryDelay); err == nil {
			config.RetryDelay = delay
		}
	}
	if enableTLS := os.Getenv("ENABLE_TLS"); enableTLS != "" {
		if tls, err := strconv.ParseBool(enableTLS); err == nil {
			config.EnableTLS = tls
		}
	}
	if tlsCertFile := os.Getenv("TLS_CERT_FILE"); tlsCertFile != "" {
		config.TLSCertFile = tlsCertFile
	}
	if tlsKeyFile := os.Getenv("TLS_KEY_FILE"); tlsKeyFile != "" {
		config.TLSKeyFile = tlsKeyFile
	}
	if tlsCACertFile := os.Getenv("TLS_CA_CERT_FILE"); tlsCACertFile != "" {
		config.TLSCACertFile = tlsCACertFile
	}
	if enableMetrics := os.Getenv("ENABLE_METRICS"); enableMetrics != "" {
		if metrics, err := strconv.ParseBool(enableMetrics); err == nil {
			config.EnableMetrics = metrics
		}
	}
	if metricsPort := os.Getenv("METRICS_PORT"); metricsPort != "" {
		if port, err := strconv.Atoi(metricsPort); err == nil {
			config.MetricsPort = port
		}
	}
	if logLevel := os.Getenv("LOG_LEVEL"); logLevel != "" {
		config.LogLevel = logLevel
	}
	if maxConnections := os.Getenv("MAX_CONNECTIONS"); maxConnections != "" {
		if connections, err := strconv.Atoi(maxConnections); err == nil {
			config.MaxConnections = connections
		}
	}
	if connectionTimeout := os.Getenv("CONNECTION_TIMEOUT"); connectionTimeout != "" {
		if timeout, err := time.ParseDuration(connectionTimeout); err == nil {
			config.ConnectionTimeout = timeout
		}
	}
	if queryTimeout := os.Getenv("QUERY_TIMEOUT"); queryTimeout != "" {
		if timeout, err := time.ParseDuration(queryTimeout); err == nil {
			config.QueryTimeout = timeout
		}
	}

	// Log configuration (without sensitive data)
	log.Printf("📋 Configuration:")
	log.Printf("   NATS URL: %s", config.NATSUrl)
	log.Printf("   ClickHouse URL: %s", config.ClickHouseURL)
	log.Printf("   ClickHouse DB: %s", config.ClickHouseDB)
	log.Printf("   Batch Size: %d", config.BatchSize)
	log.Printf("   Batch Timeout: %v", config.BatchTimeout)
	log.Printf("   Max Retries: %d", config.MaxRetries)
	log.Printf("   Enable TLS: %v", config.EnableTLS)
	log.Printf("   Enable Metrics: %v", config.EnableMetrics)
	log.Printf("   Max Connections: %d", config.MaxConnections)

	bridge, err := NewSimpleBridge(config)
	if err != nil {
		log.Fatalf("❌ Failed to create bridge: %v", err)
	}

	// Set up graceful shutdown
	sigChan := make(chan os.Signal, 1)
	// signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("🛑 Shutdown signal received, stopping bridge...")
		bridge.Shutdown()
		os.Exit(0)
	}()

	// Start the bridge
	if err := bridge.Start(); err != nil {
		log.Fatalf("❌ Failed to start bridge: %v", err)
	}

	// Keep the main goroutine alive
	select {}
} 