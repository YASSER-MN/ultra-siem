package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"net/http"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/nats-io/nats.go"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
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
	nc              *nats.Conn
	js              nats.JetStreamContext
	db              driver.Conn
	threatsStream   nats.StreamInfo
	realStream      nats.StreamInfo
	stats           *BridgeStats
	mu              sync.RWMutex
	ctx             context.Context
	cancel          context.CancelFunc
	metrics         *BridgeMetrics
}

// BridgeStats holds runtime statistics
type BridgeStats struct {
	eventsProcessed uint64
	eventsPerSecond float64
	errors          uint64
	lastUpdate      time.Time
	mu              sync.RWMutex
}

// BridgeMetrics holds Prometheus metrics
type BridgeMetrics struct {
	eventsProcessed prometheus.Counter
	eventsPerSecond prometheus.Gauge
	processingTime   prometheus.Histogram
	errorRate       prometheus.Counter
	queueSize       prometheus.Gauge
}

func NewSIEMBridge() (*SIEMBridge, error) {
	ctx, cancel := context.WithCancel(context.Background())

	// Initialize metrics
	metrics := &BridgeMetrics{
		eventsProcessed: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "ultra_siem_events_processed_total",
			Help: "Total number of events processed",
		}),
		eventsPerSecond: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "ultra_siem_events_per_second",
			Help: "Events processed per second",
		}),
		processingTime: prometheus.NewHistogram(prometheus.HistogramOpts{
			Name:    "ultra_siem_processing_duration_seconds",
			Help:    "Time spent processing events",
			Buckets: prometheus.DefBuckets,
		}),
		errorRate: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "ultra_siem_errors_total",
			Help: "Total number of errors",
		}),
		queueSize: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "ultra_siem_queue_size",
			Help: "Number of events in processing queue",
		}),
	}

	// Register metrics
	prometheus.MustRegister(
		metrics.eventsProcessed,
		metrics.eventsPerSecond,
		metrics.processingTime,
		metrics.errorRate,
		metrics.queueSize,
	)

	// Connect to NATS with proper error handling
	var err error
	nc, err := nats.Connect(nats.DefaultURL,
		nats.Name("Ultra SIEM Bridge"),
		nats.ReconnectWait(time.Second),
		nats.MaxReconnects(-1),
		nats.DisconnectErrHandler(func(nc *nats.Conn, err error) {
			log.Printf("❌ NATS disconnected: %v", err)
		}),
		nats.ReconnectHandler(func(nc *nats.Conn) {
			log.Printf("✅ NATS reconnected")
		}),
		nats.ErrorHandler(func(nc *nats.Conn, sub *nats.Subscription, err error) {
			log.Printf("❌ NATS error: %v", err)
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	// Get JetStream context
	js, err := nc.JetStream()
	if err != nil {
		return nil, fmt.Errorf("failed to create JetStream context: %w", err)
	}

	// Create streams with proper error handling
	threatsStream, err := js.AddStream(&nats.StreamConfig{
		Name:     "THREATS",
		Subjects: []string{"ultra-siem.threats"},
		Storage:  nats.FileStorage,
		MaxAge:   24 * time.Hour,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create stream: %w", err)
	}

	realStream, err := js.AddStream(&nats.StreamConfig{
		Name:     "REAL_DETECTION",
		Subjects: []string{"ultra-siem.real"},
		Storage:  nats.FileStorage,
		MaxAge:   24 * time.Hour,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create real detection stream: %w", err)
	}

	// Connect to ClickHouse with proper error handling
	db, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{"localhost:9000"},
		Auth: clickhouse.Auth{
			Database: "ultra_siem",
			Username: "admin",
			Password: "admin",
		},
		Settings: clickhouse.Settings{
			"max_execution_time": 60,
		},
		Debug: false,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to ClickHouse: %w", err)
	}

	// Test database connection
	if err := db.Ping(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping ClickHouse: %w", err)
	}

	// Create table if not exists with proper error handling
	if err := createTableIfNotExists(ctx, db); err != nil {
		return nil, fmt.Errorf("failed to create table: %w", err)
	}

	return &SIEMBridge{
		nc:            nc,
		js:            js,
		db:            db,
		threatsStream: *threatsStream,
		realStream:    *realStream,
		stats:         &BridgeStats{lastUpdate: time.Now()},
		ctx:           ctx,
		cancel:        cancel,
		metrics:       metrics,
	}, nil
}

func createTableIfNotExists(ctx context.Context, db driver.Conn) error {
	query := `
		CREATE TABLE IF NOT EXISTS ultra_siem.threats (
			id UUID DEFAULT generateUUIDv4(),
			timestamp DateTime64(3) DEFAULT now(),
			threat_type LowCardinality(String),
			confidence Float32,
			source_ip IPv4,
			destination_ip IPv4,
			source_port UInt16,
			destination_port UInt16,
			protocol LowCardinality(String),
			payload String,
			metadata JSON,
			severity UInt8,
			status LowCardinality(String) DEFAULT 'new',
			created_at DateTime64(3) DEFAULT now()
		) ENGINE = MergeTree()
		PARTITION BY toYYYYMM(timestamp)
		ORDER BY (timestamp, threat_type, source_ip)
		TTL timestamp + INTERVAL 90 DAY
		SETTINGS index_granularity = 8192
	`

	return db.Exec(ctx, query)
}

func (b *SIEMBridge) Start() error {
	log.Println("🚀 Starting Ultra SIEM Bridge...")

	// Start metrics server
	go b.startMetricsServer()

	// Start event processing
	go func() {
		if err := b.processEvents(); err != nil {
			log.Printf("❌ Error processing events: %v", err)
			b.metrics.errorRate.Inc()
		}
	}()

	// Start statistics reporting
	go b.reportStats()

	log.Println("✅ Ultra SIEM Bridge started successfully")
	return nil
}

func (b *SIEMBridge) processEvents() error {
	// Subscribe to threats.detected with proper error handling
	threatsSub, err := b.js.Subscribe("ultra-siem.threats", b.handleThreatEvent)
	if err != nil {
		return fmt.Errorf("failed to subscribe to threats.detected: %w", err)
	}
	defer threatsSub.Unsubscribe()

	// Subscribe to threats.real with proper error handling
	realSub, err := b.js.Subscribe("ultra-siem.real", b.handleRealEvent)
	if err != nil {
		return fmt.Errorf("failed to subscribe to threats.real: %w", err)
	}
	defer realSub.Unsubscribe()

	// Keep the service running
	select {
	case <-b.ctx.Done():
		return b.ctx.Err()
	}
}

func (b *SIEMBridge) handleThreatEvent(msg *nats.Msg) {
	start := time.Now()
	defer func() {
		b.metrics.processingTime.Observe(time.Since(start).Seconds())
		b.metrics.eventsProcessed.Inc()
	}()

	var event ThreatEvent
	if err := json.Unmarshal(msg.Data, &event); err != nil {
		log.Printf("❌ Error unmarshaling legacy event: %v", err)
		b.metrics.errorRate.Inc()
		return
	}

	// Process the event
	if err := b.processThreatEvent(&event); err != nil {
		log.Printf("❌ Error processing threat event: %v", err)
		b.metrics.errorRate.Inc()
		return
	}

	// Update statistics
	b.updateStats()
}

func (b *SIEMBridge) handleRealEvent(msg *nats.Msg) {
	start := time.Now()
	defer func() {
		b.metrics.processingTime.Observe(time.Since(start).Seconds())
		b.metrics.eventsProcessed.Inc()
	}()

	var realEvent RealThreatEvent
	if err := json.Unmarshal(msg.Data, &realEvent); err != nil {
		log.Printf("❌ Error unmarshaling real event: %v", err)
		b.metrics.errorRate.Inc()
		return
	}

	// Convert to ThreatEvent
	event := ThreatEvent{
		EventTime:  time.Unix(realEvent.Timestamp, 0),
		SourceIP:   realEvent.SourceIP,
		ThreatType: realEvent.ThreatType,
		Severity:   fmt.Sprintf("%d", realEvent.Severity),
		Message:    realEvent.Payload,
		RawLog:     realEvent.Payload,
		Country:    "",
		ASN:        0,
		IsTor:      0,
		Confidence: float32(realEvent.Confidence),
		Source:     realEvent.Source,
		Details:    fmt.Sprintf("%v", realEvent.Details),
	}

	// Process the event
	if err := b.processThreatEvent(&event); err != nil {
		log.Printf("❌ Error processing real event: %v", err)
		b.metrics.errorRate.Inc()
		return
	}

	// Update statistics
	b.updateStats()
}

func (b *SIEMBridge) processThreatEvent(event *ThreatEvent) error {
	// Prepare batch insert with proper error handling
	batch, err := b.db.PrepareBatch(b.ctx, "INSERT INTO ultra_siem.threats")
	if err != nil {
		return fmt.Errorf("error preparing batch: %w", err)
	}

	// Add event to batch with proper error handling
	err = batch.Append(
		generateUUID(),
		event.EventTime,
		event.ThreatType,
		event.Confidence,
		event.SourceIP,
		"", // destination_ip - extract from details if available
		0,  // source_port
		0,  // destination_port
		"", // protocol
		event.Message,
		fmt.Sprintf("{\"source_ip\":\"%s\",\"country\":\"%s\",\"asn\":%d,\"is_tor\":%d}",
			event.SourceIP, event.Country, event.ASN, event.IsTor),
		event.Severity,
		"new",
	)
	if err != nil {
		return fmt.Errorf("error appending to batch: %w", err)
	}

	// Send batch with proper error handling
	if err := batch.Send(); err != nil {
		return fmt.Errorf("error sending batch: %w", err)
	}

	log.Printf("✅ Processed threat event: %s (confidence: %.2f)", event.ThreatType, event.Confidence)
	return nil
}

func (b *SIEMBridge) updateStats() {
	b.stats.mu.Lock()
	defer b.stats.mu.Unlock()

	b.stats.eventsProcessed++
	now := time.Now()
	elapsed := now.Sub(b.stats.lastUpdate).Seconds()
	if elapsed > 0 {
		b.stats.eventsPerSecond = float64(b.stats.eventsProcessed) / elapsed
	}
	b.stats.lastUpdate = now

	// Update Prometheus metrics
	b.metrics.eventsPerSecond.Set(b.stats.eventsPerSecond)
}

func (b *SIEMBridge) reportStats() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			b.stats.mu.RLock()
			processed := b.stats.eventsProcessed
			rate := b.stats.eventsPerSecond
			errors := b.stats.errors
			b.stats.mu.RUnlock()

			log.Printf("📊 Stats: Processed=%d, Rate=%.2f/sec, Errors=%d",
				processed, rate, errors)
		case <-b.ctx.Done():
			return
		}
	}
}

func (b *SIEMBridge) startMetricsServer() {
	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	log.Println("📊 Starting metrics server on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Printf("❌ Metrics server error: %v", err)
	}
}

func (b *SIEMBridge) Shutdown() {
	log.Println("🛑 Shutting down Ultra SIEM Bridge...")
	b.cancel()
	b.nc.Close()
	b.db.Close()
	log.Println("✅ Ultra SIEM Bridge shutdown complete")
}

func generateUUID() string {
	// Simple UUID generation - in production, use a proper UUID library
	return fmt.Sprintf("%d-%d-%d-%d", 
		time.Now().UnixNano(),
		time.Now().Unix(),
		time.Now().UnixNano()%1000,
		time.Now().UnixNano()%10000)
}

func main() {
	bridge, err := NewSIEMBridge()
	if err != nil {
		log.Fatalf("❌ Failed to create SIEM bridge: %v", err)
	}

	if err := bridge.Start(); err != nil {
		log.Fatalf("❌ Failed to start SIEM bridge: %v", err)
	}

	// Wait for shutdown signal
	select {}
} 