package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"sync"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/nats-io/nats.go"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

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

type SIEMBridge struct {
	nats       *nats.Conn
	js         nats.JetStreamContext
	clickhouse driver.Conn
	metrics    *Metrics
	batchMutex sync.Mutex
	eventBatch []ThreatEvent
}

type Metrics struct {
	eventsProcessed prometheus.Counter
	eventsDropped   prometheus.Counter
	latency         prometheus.Histogram
	batchSize       prometheus.Histogram
}

func setupMetrics() *Metrics {
	return &Metrics{
		eventsProcessed: promauto.NewCounter(prometheus.CounterOpts{
			Name: "siem_events_processed_total",
			Help: "Total number of events processed",
		}),
		eventsDropped: promauto.NewCounter(prometheus.CounterOpts{
			Name: "siem_events_dropped_total",
			Help: "Total number of events dropped",
		}),
		latency: promauto.NewHistogram(prometheus.HistogramOpts{
			Name:    "siem_processing_latency_seconds",
			Help:    "Processing latency distribution",
			Buckets: prometheus.ExponentialBuckets(0.001, 2, 10),
		}),
		batchSize: promauto.NewHistogram(prometheus.HistogramOpts{
			Name:    "siem_batch_size",
			Help:    "Batch size distribution",
			Buckets: prometheus.LinearBuckets(100, 100, 10),
		}),
	}
}

func loadTLSConfig(certFile, keyFile, caFile string) (*tls.Config, error) {
	// Load client certificate
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		return nil, fmt.Errorf("failed to load client certificate: %w", err)
	}

	// Load CA certificate
	caCert, err := ioutil.ReadFile(caFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read CA certificate: %w", err)
	}

	caCertPool := x509.NewCertPool()
	if !caCertPool.AppendCertsFromPEM(caCert) {
		return nil, fmt.Errorf("failed to append CA certificate")
	}

	return &tls.Config{
		Certificates: []tls.Certificate{cert},
		RootCAs:      caCertPool,
		MinVersion:   tls.VersionTLS13,
		CipherSuites: []uint16{
			tls.TLS_AES_256_GCM_SHA384,
			tls.TLS_CHACHA20_POLY1305_SHA256,
		},
		CurvePreferences: []tls.CurveID{
			tls.X25519,
			tls.CurveP384,
		},
	}, nil
}

func NewSIEMBridge() (*SIEMBridge, error) {
	bridge := &SIEMBridge{
		metrics:    setupMetrics(),
		eventBatch: make([]ThreatEvent, 0, 1000),
	}

	// Setup mTLS configuration
	tlsConfig, err := loadTLSConfig(
		os.Getenv("TLS_CERT_FILE"),
		os.Getenv("TLS_KEY_FILE"),
		os.Getenv("TLS_CA_FILE"),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to setup TLS: %w", err)
	}

	// Connect to NATS with mTLS
	natsURL := os.Getenv("NATS_URL")
	if natsURL == "" {
		natsURL = "tls://nats:4222"
	}

	bridge.nats, err = nats.Connect(natsURL,
		nats.Secure(tlsConfig),
		nats.UserCredentials(os.Getenv("NATS_CREDS_FILE")),
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

	// Connect to ClickHouse with mTLS
	clickhouseURL := os.Getenv("CLICKHOUSE_URL")
	if clickhouseURL == "" {
		clickhouseURL = "clickhouse:9440"
	}

	bridge.clickhouse, err = clickhouse.Open(&clickhouse.Options{
		Addr: []string{clickhouseURL},
		Auth: clickhouse.Auth{
			Database: os.Getenv("CLICKHOUSE_DB"),
			Username: os.Getenv("CLICKHOUSE_USER"),
			Password: os.Getenv("CLICKHOUSE_PASSWORD"),
		},
		TLS: tlsConfig,
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
	// Subscribe to threat events
	sub, err := b.js.PullSubscribe("threats.detected", "clickhouse-bridge",
		nats.Durable("clickhouse-bridge"),
		nats.AckExplicit(),
		nats.MaxDeliver(3),
		nats.AckWait(30*time.Second),
	)
	if err != nil {
		return fmt.Errorf("failed to subscribe: %w", err)
	}

	// Start batch processor
	go b.batchProcessor()

	log.Println("✅ SIEM Bridge started - processing events...")

	for {
		// Fetch messages in batches
		msgs, err := sub.Fetch(100, nats.MaxWait(5*time.Second))
		if err != nil {
			if err == nats.ErrTimeout {
				continue
			}
			log.Printf("Error fetching messages: %v", err)
			continue
		}

		for _, msg := range msgs {
			start := time.Now()

			var event ThreatEvent
			if err := json.Unmarshal(msg.Data, &event); err != nil {
				log.Printf("Failed to unmarshal event: %v", err)
				b.metrics.eventsDropped.Inc()
				msg.Ack()
				continue
			}

			// Add to batch
			b.addToBatch(event)
			b.metrics.eventsProcessed.Inc()
			b.metrics.latency.Observe(time.Since(start).Seconds())

			msg.Ack()
		}
	}
}

func (b *SIEMBridge) addToBatch(event ThreatEvent) {
	b.batchMutex.Lock()
	defer b.batchMutex.Unlock()

	b.eventBatch = append(b.eventBatch, event)
	
	// Flush if batch is full
	if len(b.eventBatch) >= 1000 {
		b.flushBatch()
	}
}

func (b *SIEMBridge) flushBatch() {
	if len(b.eventBatch) == 0 {
		return
	}

	batch, err := b.clickhouse.PrepareBatch(context.Background(),
		`INSERT INTO siem.threats (
			event_time, src_ip, threat_type, severity, message, 
			raw_log, country, asn, is_tor, confidence
		)`)
	if err != nil {
		log.Printf("Failed to prepare batch: %v", err)
		b.metrics.eventsDropped.Add(float64(len(b.eventBatch)))
		b.eventBatch = b.eventBatch[:0]
		return
	}

	for _, event := range b.eventBatch {
		err = batch.Append(
			event.EventTime,
			event.SourceIP,
			event.ThreatType,
			event.Severity,
			event.Message,
			event.RawLog,
			event.Country,
			event.ASN,
			event.IsTor,
			event.Confidence,
		)
		if err != nil {
			log.Printf("Failed to append to batch: %v", err)
			continue
		}
	}

	if err := batch.Send(); err != nil {
		log.Printf("Failed to send batch: %v", err)
		b.metrics.eventsDropped.Add(float64(len(b.eventBatch)))
	} else {
		b.metrics.batchSize.Observe(float64(len(b.eventBatch)))
		log.Printf("✅ Inserted %d events into ClickHouse", len(b.eventBatch))
	}

	b.eventBatch = b.eventBatch[:0]
}

func (b *SIEMBridge) batchProcessor() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		b.batchMutex.Lock()
		if len(b.eventBatch) > 0 {
			b.flushBatch()
		}
		b.batchMutex.Unlock()
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
	log.Println("🚀 Starting Ultra SIEM Bridge with mTLS...")

	bridge, err := NewSIEMBridge()
	if err != nil {
		log.Fatalf("Failed to create bridge: %v", err)
	}
	defer bridge.Close()

	if err := bridge.processEvents(); err != nil {
		log.Fatalf("Failed to process events: %v", err)
	}
} 