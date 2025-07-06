package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/nats-io/nats.go"
)

// ThreatEvent represents the original threat event format
type ThreatEvent struct {
	EventTime   time.Time `json:"timestamp"`
	SourceIP    string    `json:"source_ip"`
	ThreatType  string    `json:"threat_type"`
	Severity    string    `json:"severity"`
	Message     string    `json:"message"`
	RawLog      string    `json:"raw_log"`
	Country     string    `json:"country"`
	ASN         uint32    `json:"asn"`
	IsTor       uint8     `json:"is_tor"`
	Confidence  float32   `json:"confidence"`
}

// RealThreatEvent represents the new real detection event format
type RealThreatEvent struct {
	Timestamp   int64             `json:"timestamp"`
	SourceIP    string            `json:"source_ip"`
	ThreatType  string            `json:"threat_type"`
	Payload     string            `json:"payload"`
	Severity    int               `json:"severity"`
	Confidence  float64           `json:"confidence"`
	Source      string            `json:"source"`
	Details     map[string]string `json:"details"`
}

// UnifiedThreatEvent represents the blended event format for storage
type UnifiedThreatEvent struct {
	Timestamp   time.Time
	SourceIP    string
	ThreatType  string
	Severity    string
	Message     string
	RawLog      string
	Country     string
	ASN         uint32
	IsTor       uint8
	Confidence  float32
	Source      string
	Details     string
}

// SIEMBridge handles both old and new threat processing
type SIEMBridge struct {
	nats           *nats.Conn
	js             nats.JetStreamContext
	clickhouse     driver.Conn
	batchMutex     sync.Mutex
	eventBatch     []UnifiedThreatEvent
	reportedEvents sync.Map // For deduplication
}

func NewSIEMBridge() (*SIEMBridge, error) {
	bridge := &SIEMBridge{
		eventBatch: make([]UnifiedThreatEvent, 0, 1000),
	}

	// Connect to NATS (no TLS for demo)
	natsURL := os.Getenv("NATS_URL")
	if natsURL == "" {
		natsURL = "nats://127.0.0.1:4222"
	}

	var err error
	bridge.nats, err = nats.Connect(natsURL,
		nats.MaxReconnects(-1),
		nats.ReconnectWait(time.Second*2),
		nats.DisconnectErrHandler(func(nc *nats.Conn, err error) {
			log.Printf("NATS disconnected: %v", err)
		}),
		nats.ReconnectHandler(func(nc *nats.Conn) {
			log.Printf("NATS reconnected to %v", nc.ConnectedUrl())
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	// Create JetStream context
	bridge.js, err = bridge.nats.JetStream()
	if err != nil {
		return nil, fmt.Errorf("failed to create JetStream context: %w", err)
	}

	// Create stream if it doesn't exist
	stream, err := bridge.js.StreamInfo("THREATS")
	if err != nil {
		// Stream doesn't exist, create it
		_, err = bridge.js.AddStream(&nats.StreamConfig{
			Name:     "THREATS",
			Subjects: []string{"threats.detected", "threats.real"},
			Storage:  nats.FileStorage,
		})
		if err != nil {
			return nil, fmt.Errorf("failed to create stream: %w", err)
		}
		log.Printf("✅ Created NATS stream: THREATS")
	} else {
		log.Printf("✅ NATS stream exists: %s", stream.Config.Name)
	}

	// Connect to ClickHouse (no TLS for demo)
	clickhouseURL := os.Getenv("CLICKHOUSE_URL")
	if clickhouseURL == "" {
		clickhouseURL = "127.0.0.1:8123"
	}

	clickhouseDB := os.Getenv("CLICKHOUSE_DB")
	if clickhouseDB == "" {
		clickhouseDB = "siem"
	}

	clickhouseUser := os.Getenv("CLICKHOUSE_USER")
	if clickhouseUser == "" {
		clickhouseUser = "admin"
	}

	clickhousePassword := os.Getenv("CLICKHOUSE_PASSWORD")
	if clickhousePassword == "" {
		clickhousePassword = "admin"
	}

	bridge.clickhouse, err = clickhouse.Open(&clickhouse.Options{
		Addr: []string{clickhouseURL},
		Auth: clickhouse.Auth{
			Database: clickhouseDB,
			Username: clickhouseUser,
			Password: clickhousePassword,
		},
		Settings: clickhouse.Settings{
			"max_execution_time":             300,
			"max_memory_usage":               "8000000000",
			"use_uncompressed_cache":         1,
			"async_insert":                   1,
			"wait_for_async_insert":          0,
			"async_insert_max_data_size":     "100000000",
			"async_insert_busy_timeout_ms":   200,
		},
		Compression: &clickhouse.Compression{
			Method: clickhouse.CompressionZSTD,
		},
		MaxOpenConns:    10,
		MaxIdleConns:    5,
		ConnMaxLifetime: time.Hour,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to ClickHouse: %w", err)
	}

	return bridge, nil
}

func (b *SIEMBridge) processEvents() error {
	// Subscribe to both old and new threat events
	sub1, err := b.js.PullSubscribe("threats.detected", "clickhouse-bridge-legacy",
		nats.AckExplicit(),
		nats.MaxDeliver(3),
		nats.AckWait(30*time.Second),
	)
	if err != nil {
		return fmt.Errorf("failed to subscribe to threats.detected: %w", err)
	}

	sub2, err := b.js.PullSubscribe("threats.real", "clickhouse-bridge-real",
		nats.AckExplicit(),
		nats.MaxDeliver(3),
		nats.AckWait(30*time.Second),
	)
	if err != nil {
		return fmt.Errorf("failed to subscribe to threats.real: %w", err)
	}

	// Start batch processor
	go b.batchProcessor()

	log.Printf("🚀 Ultra SIEM Go Data Processor Starting...")
	log.Printf("✅ Connected to NATS")
	log.Printf("📡 Listening for threat events (legacy + real)...")
	log.Printf("🔄 Blended processing: Old + New threat detection")

	// Process both subscription types
	go b.processSubscription(sub1, "legacy")
	go b.processSubscription(sub2, "real")

	// Keep main thread alive
	select {}
}

func (b *SIEMBridge) processSubscription(sub *nats.Subscription, source string) {
	for {
		msgs, err := sub.Fetch(100, nats.MaxWait(5*time.Second))
		if err != nil {
			if err == nats.ErrTimeout {
				continue
			}
			log.Printf("Error fetching messages from %s: %v", source, err)
			continue
		}

		for _, msg := range msgs {
			var unifiedEvent UnifiedThreatEvent

			if source == "legacy" {
				var event ThreatEvent
				if err := json.Unmarshal(msg.Data, &event); err != nil {
					log.Printf("Error unmarshaling legacy event: %v", err)
					msg.Ack()
					continue
				}
				unifiedEvent = b.convertLegacyEvent(event)
			} else {
				var event RealThreatEvent
				if err := json.Unmarshal(msg.Data, &event); err != nil {
					log.Printf("Error unmarshaling real event: %v", err)
					msg.Ack()
					continue
				}
				unifiedEvent = b.convertRealEvent(event)
			}

			// Check for duplicates
			if !b.isDuplicate(unifiedEvent) {
				b.addToBatch(unifiedEvent)
				log.Printf("📥 %s THREAT: %s from %s (confidence: %.2f)", 
					source, unifiedEvent.ThreatType, unifiedEvent.Source, unifiedEvent.Confidence)
			} else {
				log.Printf("🔄 Duplicate %s threat ignored: %s", source, unifiedEvent.ThreatType)
			}

			msg.Ack()
		}
	}
}

func (b *SIEMBridge) convertLegacyEvent(event ThreatEvent) UnifiedThreatEvent {
	details, _ := json.Marshal(map[string]string{
		"source": "legacy",
		"event_time": event.EventTime.Format(time.RFC3339),
	})

	return UnifiedThreatEvent{
		Timestamp:  event.EventTime,
		SourceIP:   event.SourceIP,
		ThreatType: event.ThreatType,
		Severity:   event.Severity,
		Message:    event.Message,
		RawLog:     event.RawLog,
		Country:    event.Country,
		ASN:        event.ASN,
		IsTor:      event.IsTor,
		Confidence: event.Confidence,
		Source:     "legacy",
		Details:    string(details),
	}
}

func (b *SIEMBridge) convertRealEvent(event RealThreatEvent) UnifiedThreatEvent {
	details, _ := json.Marshal(event.Details)

	return UnifiedThreatEvent{
		Timestamp:  time.Unix(event.Timestamp, 0),
		SourceIP:   event.SourceIP,
		ThreatType: event.ThreatType,
		Severity:   fmt.Sprintf("%d", event.Severity),
		Message:    event.Payload,
		RawLog:     event.Payload,
		Country:    "",
		ASN:        0,
		IsTor:      0,
		Confidence: float32(event.Confidence),
		Source:     event.Source,
		Details:    string(details),
	}
}

func (b *SIEMBridge) isDuplicate(event UnifiedThreatEvent) bool {
	key := fmt.Sprintf("%s:%s:%s", event.Source, event.ThreatType, event.SourceIP)
	
	if _, exists := b.reportedEvents.Load(key); exists {
		return true
	}
	
	// Store for 60 seconds to prevent duplicates
	b.reportedEvents.Store(key, time.Now())
	
	// Clean up old entries after 60 seconds
	go func() {
		time.Sleep(60 * time.Second)
		b.reportedEvents.Delete(key)
	}()
	
	return false
}

func (b *SIEMBridge) addToBatch(event UnifiedThreatEvent) {
	b.batchMutex.Lock()
	defer b.batchMutex.Unlock()

	b.eventBatch = append(b.eventBatch, event)

	// Flush if batch is full
	if len(b.eventBatch) >= 100 {
		go b.flushBatch()
	}
}

func (b *SIEMBridge) flushBatch() {
	b.batchMutex.Lock()
	if len(b.eventBatch) == 0 {
		b.batchMutex.Unlock()
		return
	}

	batch := make([]UnifiedThreatEvent, len(b.eventBatch))
	copy(batch, b.eventBatch)
	b.eventBatch = b.eventBatch[:0]
	b.batchMutex.Unlock()

	// Insert batch into ClickHouse
	ctx := context.Background()
	
	query := `
		INSERT INTO siem.threats (
			timestamp, source_ip, threat_type, severity, message, 
			raw_log, country, asn, is_tor, confidence, source, details
		) VALUES (
			?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
		)
	`

	batchInsert, err := b.clickhouse.PrepareBatch(ctx, query)
	if err != nil {
		log.Printf("Error preparing batch: %v", err)
		return
	}

	for _, event := range batch {
		err := batchInsert.Append(
			event.Timestamp,
			event.SourceIP,
			event.ThreatType,
			event.Severity,
			event.Message,
			event.RawLog,
			event.Country,
			event.ASN,
			event.IsTor,
			event.Confidence,
			event.Source,
			event.Details,
		)
		if err != nil {
			log.Printf("Error appending to batch: %v", err)
		}
	}

	if err := batchInsert.Send(); err != nil {
		log.Printf("Error sending batch: %v", err)
	} else {
		log.Printf("📊 Processed %d unified threat events", len(batch))
	}
}

func (b *SIEMBridge) batchProcessor() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		b.flushBatch()
	}
}

func (b *SIEMBridge) Close() {
	if b.nats != nil {
		b.nats.Close()
	}
	if b.clickhouse != nil {
		b.clickhouse.Close()
	}
}

func main() {
	bridge, err := NewSIEMBridge()
	if err != nil {
		log.Fatalf("Failed to create bridge: %v", err)
	}
	defer bridge.Close()

	if err := bridge.processEvents(); err != nil {
		log.Fatalf("Error processing events: %v", err)
	}
} 