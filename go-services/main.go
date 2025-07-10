// Package main provides the Ultra SIEM Go Data Processor service.
//
// This service is responsible for:
// - Processing threat events from NATS messaging system
// - Storing events in ClickHouse database
// - Providing high-performance data processing pipeline
// - Real-time statistics and monitoring
//
// Architecture:
// - NATS consumer for event ingestion
// - Lock-free ring buffer for event buffering
// - Multi-worker ClickHouse insertion
// - Real-time statistics reporting
//
// Configuration:
// - NATS_URL: NATS server URL (default: nats://localhost:4222)
// - NATS_PROCESSOR_PASSWORD: NATS authentication password
// - CLICKHOUSE_HOST: ClickHouse server address (default: clickhouse:9000)
// - CLICKHOUSE_USER: ClickHouse username (default: admin)
// - CLICKHOUSE_PASSWORD: ClickHouse password (default: admin)
//
// Usage:
//
//	go run main.go
//
// The service will automatically:
// 1. Connect to NATS and ClickHouse
// 2. Create required database tables
// 3. Start event processing workers
// 4. Begin consuming threat events
// 5. Report statistics every 5 seconds
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"runtime"
	"sync/atomic"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/nats-io/nats.go"
)

// ThreatEvent represents a security threat event in the SIEM system.
//
// Each event contains metadata about a detected threat including
// source information, threat classification, and confidence metrics.
type ThreatEvent struct {
	// Timestamp when the threat was detected (Unix timestamp in seconds)
	Timestamp uint64 `json:"timestamp"`
	// Source IP address where the threat originated
	SourceIP string `json:"source_ip"`
	// Type/category of the threat (e.g., "malware", "ddos", "sql_injection")
	ThreatType string `json:"threat_type"`
	// Raw payload or additional data about the threat
	Payload string `json:"payload"`
	// Severity level (0-255, higher = more severe)
	Severity uint8 `json:"severity"`
	// Confidence score (0.0-1.0, higher = more confident)
	Confidence float32 `json:"confidence"`
}

// RingBuffer provides a lock-free circular buffer for threat events.
//
// This implementation uses atomic operations to ensure thread-safety
// without locks, enabling high-performance concurrent access.
// The buffer size must be a power of 2 for efficient modulo operations.
type RingBuffer struct {
	head   uint64           // Current read position
	tail   uint64           // Current write position
	mask   uint64           // Bit mask for efficient modulo (size - 1)
	buffer []*ThreatEvent   // Circular array of events
}

// NewRingBuffer creates a new ring buffer with the specified size.
//
// Args:
//   size: Buffer size (must be a power of 2)
//
// Returns:
//   *RingBuffer: New ring buffer instance
//
// Panics:
//   If size is not a power of 2
//
// Example:
//   buffer := NewRingBuffer(1024) // Creates 1K event buffer
func NewRingBuffer(size uint64) *RingBuffer {
	// Ensure size is power of 2 for efficient modulo operations
	if size&(size-1) != 0 {
		panic("Ring buffer size must be power of 2")
	}
	
	return &RingBuffer{
		head:   0,
		tail:   0,
		mask:   size - 1,
		buffer: make([]*ThreatEvent, size),
	}
}

// Put adds an event to the ring buffer.
//
// This method is thread-safe and uses atomic operations to ensure
// concurrent access without locks. If the buffer is full, it will
// yield the CPU and retry.
//
// Args:
//   event: Threat event to add to buffer
//
// Returns:
//   bool: true if event was added successfully, false if buffer is full
//
// Example:
//   success := buffer.Put(&ThreatEvent{...})
//   if !success {
//       log.Println("Buffer full, event dropped")
//   }
func (rb *RingBuffer) Put(event *ThreatEvent) bool {
	for {
		tail := atomic.LoadUint64(&rb.tail)
		next := (tail + 1) & rb.mask
		
		if next == atomic.LoadUint64(&rb.head) {
			// Buffer is full, yield CPU and retry
			runtime.Gosched()
			return false
		}
		
		if atomic.CompareAndSwapUint64(&rb.tail, tail, next) {
			rb.buffer[tail] = event
			return true
		}
	}
}

// Get retrieves an event from the ring buffer.
//
// This method is thread-safe and uses atomic operations. If the buffer
// is empty, it will yield the CPU and continue trying until an event
// becomes available.
//
// Returns:
//   *ThreatEvent: Next event from buffer, or nil if buffer is empty
//
// Note:
//   This method blocks until an event is available. For non-blocking
//   behavior, check buffer status before calling.
//
// Example:
//   event := buffer.Get()
//   if event != nil {
//       processEvent(event)
//   }
func (rb *RingBuffer) Get() *ThreatEvent {
	for {
		head := atomic.LoadUint64(&rb.head)
		tail := atomic.LoadUint64(&rb.tail)
		
		if head == tail {
			// Buffer is empty, yield CPU and retry
			runtime.Gosched()
			continue
		}
		
		if atomic.CompareAndSwapUint64(&rb.head, head, (head+1)&rb.mask) {
			event := rb.buffer[head]
			rb.buffer[head] = nil // Help garbage collector
			return event
		}
	}
}

// SIEMProcessor manages the main SIEM data processing pipeline.
//
// This struct coordinates all components of the data processing system:
// - NATS connection for event ingestion
// - ClickHouse connection for data storage
// - Ring buffer for event buffering
// - Worker goroutines for parallel processing
// - Statistics tracking and reporting
type SIEMProcessor struct {
	nats       *nats.Conn    // NATS connection for messaging
	clickhouse driver.Conn   // ClickHouse connection for storage
	ringBuffer *RingBuffer   // Event buffer for processing
	stats      struct {
		processed uint64 // Total events processed successfully
		errors    uint64 // Total processing errors
	}
}

// NewSIEMProcessor creates and initializes a new SIEM processor.
//
// This function:
// 1. Connects to NATS messaging system
// 2. Connects to ClickHouse database
// 3. Creates required database tables
// 4. Initializes the ring buffer
// 5. Returns a ready-to-use processor
//
// Returns:
//   *SIEMProcessor: Initialized processor instance
//   error: Any error that occurred during initialization
//
// Example:
//   processor, err := NewSIEMProcessor()
//   if err != nil {
//       log.Fatal("Failed to create processor:", err)
//   }
func NewSIEMProcessor() (*SIEMProcessor, error) {
	// Connect to NATS with authentication
	natsURL := getEnv("NATS_URL", "nats://localhost:4222")
	natsPassword := getEnv("NATS_PROCESSOR_PASSWORD", "ultra_siem_processor_2024")
	
	opts := []nats.Option{
		nats.Name("ultra-siem-processor"),
		nats.UserInfo("processor", natsPassword),
	}
	
	nc, err := nats.Connect(natsURL, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	// Connect to ClickHouse
	clickhouseHost := getEnv("CLICKHOUSE_HOST", "clickhouse:9000")
	clickhouseUser := getEnv("CLICKHOUSE_USER", "admin")
	clickhousePassword := getEnv("CLICKHOUSE_PASSWORD", "admin")
	ch, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{clickhouseHost},
		Auth: clickhouse.Auth{
			Database: "siem",
			Username: clickhouseUser,
			Password: clickhousePassword,
		},
		Settings: clickhouse.Settings{
			"max_execution_time": 60,
		},
		Compression: &clickhouse.Compression{
			Method: clickhouse.CompressionLZ4,
		},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to ClickHouse: %w", err)
	}

	// Create table if not exists
	err = ch.Exec(context.Background(), `
		CREATE TABLE IF NOT EXISTS threats (
			timestamp DateTime64(3),
			source_ip String,
			threat_type LowCardinality(String),
			payload String,
			severity UInt8,
			confidence Float32
		) ENGINE = MergeTree()
		PARTITION BY toYYYYMM(timestamp)
		ORDER BY (timestamp, threat_type, source_ip)
		SETTINGS index_granularity = 8192
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to create table: %w", err)
	}

	return &SIEMProcessor{
		nats:       nc,
		clickhouse: ch,
		ringBuffer: NewRingBuffer(1 << 20), // 1M elements
	}, nil
}

// startWorkers launches the ClickHouse insertion worker goroutines.
//
// This method starts multiple worker goroutines (one per CPU core)
// that continuously process events from the ring buffer and insert
// them into ClickHouse in batches for optimal performance.
//
// Each worker:
// - Runs on a dedicated OS thread for better performance
// - Batches events for efficient database insertion
// - Handles insertion errors gracefully
// - Updates processing statistics
func (sp *SIEMProcessor) startWorkers() {
	numWorkers := runtime.GOMAXPROCS(0)
	log.Printf("Starting %d ClickHouse workers", numWorkers)
	
	for i := 0; i < numWorkers; i++ {
		go func(workerID int) {
			runtime.LockOSThread()
			
			// Batch for efficient inserts
			batch := make([]*ThreatEvent, 0, 1000)
			lastFlush := time.Now()
			
			for {
				event := sp.ringBuffer.Get()
				batch = append(batch, event)
				
				// Flush when batch is full or timeout reached
				if len(batch) >= 1000 || time.Since(lastFlush) > 100*time.Millisecond {
					if err := sp.insertBatch(batch); err != nil {
						log.Printf("Worker %d: Insert error: %v", workerID, err)
						atomic.AddUint64(&sp.stats.errors, 1)
					} else {
						atomic.AddUint64(&sp.stats.processed, uint64(len(batch)))
					}
					
					batch = batch[:0]
					lastFlush = time.Now()
				}
			}
		}(i)
	}
}

func (sp *SIEMProcessor) insertBatch(events []*ThreatEvent) error {
	if len(events) == 0 {
		return nil
	}
	
	batch, err := sp.clickhouse.PrepareBatch(context.Background(),
		"INSERT INTO threats (timestamp, source_ip, threat_type, payload, severity, confidence)")
	if err != nil {
		return err
	}
	
	for _, event := range events {
		err = batch.Append(
			time.Unix(int64(event.Timestamp), 0),
			event.SourceIP,
			event.ThreatType,
			event.Payload,
			event.Severity,
			event.Confidence,
		)
		if err != nil {
			return err
		}
	}
	
	return batch.Send()
}

func (sp *SIEMProcessor) startNATSConsumer() error {
	sub, err := sp.nats.Subscribe("threats.detected", func(m *nats.Msg) {
		var event ThreatEvent
		if err := json.Unmarshal(m.Data, &event); err != nil {
			log.Printf("Failed to unmarshal event: %v", err)
			return
		}
		
		// Try to put in ring buffer, drop if full
		if !sp.ringBuffer.Put(&event) {
			atomic.AddUint64(&sp.stats.errors, 1)
		}
	})
	if err != nil {
		return err
	}
	
	// Configure for high performance
	sub.SetPendingLimits(-1, -1)
	
	log.Println("NATS consumer started")
	return nil
}

func (sp *SIEMProcessor) startStatsReporter() {
	ticker := time.NewTicker(10 * time.Second)
	go func() {
		for range ticker.C {
			processed := atomic.LoadUint64(&sp.stats.processed)
			errors := atomic.LoadUint64(&sp.stats.errors)
			log.Printf("Stats: Processed=%d, Errors=%d, Rate=%.2f/sec", 
				processed, errors, float64(processed)/time.Since(time.Now()).Seconds())
		}
	}()
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func main() {
	log.Println("🚀 Ultra SIEM Go Processor Starting...")
	
	// Set GOMAXPROCS if not set
	if runtime.GOMAXPROCS(0) == 1 {
		runtime.GOMAXPROCS(runtime.NumCPU())
	}
	
	// Force GC to be more aggressive
	runtime.GC()
	
	processor, err := NewSIEMProcessor()
	if err != nil {
		log.Fatalf("Failed to create processor: %v", err)
	}
	defer processor.clickhouse.Close()
	defer processor.nats.Close()
	
	// Start workers
	processor.startWorkers()
	
	// Start NATS consumer
	if err := processor.startNATSConsumer(); err != nil {
		log.Fatalf("Failed to start NATS consumer: %v", err)
	}
	
	// Start stats reporter
	processor.startStatsReporter()
	
	log.Println("✅ Processor ready for high-performance threat processing")
	
	// Keep running
	select {}
} 