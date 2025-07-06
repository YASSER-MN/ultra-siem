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

	"github.com/nats-io/nats.go"
	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
)

type ThreatEvent struct {
	Timestamp  uint64  `json:"timestamp"`
	SourceIP   string  `json:"source_ip"`
	ThreatType string  `json:"threat_type"`
	Payload    string  `json:"payload"`
	Severity   uint8   `json:"severity"`
	Confidence float32 `json:"confidence"`
}

type RingBuffer struct {
	head   uint64
	tail   uint64
	mask   uint64
	buffer []*ThreatEvent
}

func NewRingBuffer(size uint64) *RingBuffer {
	// Ensure size is power of 2
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

func (rb *RingBuffer) Put(event *ThreatEvent) bool {
	for {
		tail := atomic.LoadUint64(&rb.tail)
		next := (tail + 1) & rb.mask
		
		if next == atomic.LoadUint64(&rb.head) {
			// Buffer is full
			runtime.Gosched()
			return false
		}
		
		if atomic.CompareAndSwapUint64(&rb.tail, tail, next) {
			rb.buffer[tail] = event
			return true
		}
	}
}

func (rb *RingBuffer) Get() *ThreatEvent {
	for {
		head := atomic.LoadUint64(&rb.head)
		tail := atomic.LoadUint64(&rb.tail)
		
		if head == tail {
			// Buffer is empty
			runtime.Gosched()
			continue
		}
		
		if atomic.CompareAndSwapUint64(&rb.head, head, (head+1)&rb.mask) {
			event := rb.buffer[head]
			rb.buffer[head] = nil // Help GC
			return event
		}
	}
}

type SIEMProcessor struct {
	nats       *nats.Conn
	clickhouse driver.Conn
	ringBuffer *RingBuffer
	stats      struct {
		processed uint64
		errors    uint64
	}
}

func NewSIEMProcessor() (*SIEMProcessor, error) {
	// Connect to NATS
	natsURL := getEnv("NATS_URL", "nats://localhost:4222")
	nc, err := nats.Connect(natsURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	// Connect to ClickHouse
	clickhouseHost := getEnv("CLICKHOUSE_HOST", "clickhouse:9000")
	ch, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{clickhouseHost},
		Auth: clickhouse.Auth{
			Database: "siem",
			Username: "admin",
			Password: "admin123",
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