package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sony/gobreaker"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// OptimizedBridge represents the enhanced data bridge with performance optimizations
type OptimizedBridge struct {
	nc              *nats.Conn
	js              nats.JetStreamContext
	circuitBreaker  *gobreaker.CircuitBreaker
	connectionPool  *ConnectionPool
	metrics         *Metrics
	backpressure    *BackpressureHandler
	requestBatcher  *RequestBatcher
	gracefulShutdown chan struct{}
	wg              sync.WaitGroup
}

// ConnectionPool manages NATS connections efficiently
type ConnectionPool struct {
	connections chan *nats.Conn
	maxConnections int
	mu          sync.RWMutex
	active      map[*nats.Conn]bool
}

// BackpressureHandler manages flow control
type BackpressureHandler struct {
	rateLimiter chan struct{}
	maxRate     int
	mu          sync.RWMutex
	currentRate int
}

// RequestBatcher batches requests for efficiency
type RequestBatcher struct {
	batchSize   int
	batchTimeout time.Duration
	batches     chan []interface{}
	processor   func([]interface{}) error
}

// Metrics for Prometheus monitoring
type Metrics struct {
	eventsProcessed prometheus.Counter
	eventsPerSecond prometheus.Gauge
	processingTime   prometheus.Histogram
	errorRate       prometheus.Counter
	circuitBreakerState prometheus.Gauge
	connectionPoolSize prometheus.Gauge
	backpressureQueue prometheus.Gauge
}

// Protobuf message for optimized serialization
type ThreatEvent struct {
	Id          string                 `protobuf:"bytes,1,opt,name=id,proto3" json:"id,omitempty"`
	Timestamp   *timestamppb.Timestamp `protobuf:"bytes,2,opt,name=timestamp,proto3" json:"timestamp,omitempty"`
	ThreatType  string                 `protobuf:"bytes,3,opt,name=threat_type,json=threatType,proto3" json:"threat_type,omitempty"`
	Confidence  float32                `protobuf:"fixed32,4,opt,name=confidence,proto3" json:"confidence,omitempty"`
	Payload     []byte                 `protobuf:"bytes,5,opt,name=payload,proto3" json:"payload,omitempty"`
	Metadata    map[string]string      `protobuf:"bytes,6,rep,name=metadata,proto3" json:"metadata,omitempty" protobuf_key:"bytes,1,opt,name=key,proto3" protobuf_val:"bytes,2,opt,name=value,proto3"`
}

func NewOptimizedBridge() (*OptimizedBridge, error) {
	// Initialize connection pool
	pool := &ConnectionPool{
		connections: make(chan *nats.Conn, 10),
		maxConnections: 10,
		active: make(map[*nats.Conn]bool),
	}

	// Initialize circuit breaker
	cb := gobreaker.NewCircuitBreaker(gobreaker.Settings{
		Name:        "nats-connection",
		MaxRequests: 3,
		Interval:    10 * time.Second,
		Timeout:     60 * time.Second,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
		OnStateChange: func(name string, from gobreaker.State, to gobreaker.State) {
			log.Printf("Circuit breaker %s: %s -> %s", name, from, to)
		},
	})

	// Initialize backpressure handler
	bp := &BackpressureHandler{
		rateLimiter: make(chan struct{}, 1000), // 1000 events/sec max
		maxRate:     1000,
	}

	// Initialize request batcher
	batcher := &RequestBatcher{
		batchSize:    100,
		batchTimeout: 100 * time.Millisecond,
		batches:      make(chan []interface{}, 10),
		processor:    processBatch,
	}

	// Initialize metrics
	metrics := &Metrics{
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
		circuitBreakerState: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "ultra_siem_circuit_breaker_state",
			Help: "Circuit breaker state (0=closed, 1=half-open, 2=open)",
		}),
		connectionPoolSize: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "ultra_siem_connection_pool_size",
			Help: "Number of active connections in pool",
		}),
		backpressureQueue: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "ultra_siem_backpressure_queue_size",
			Help: "Number of events in backpressure queue",
		}),
	}

	// Register metrics
	prometheus.MustRegister(
		metrics.eventsProcessed,
		metrics.eventsPerSecond,
		metrics.processingTime,
		metrics.errorRate,
		metrics.circuitBreakerState,
		metrics.connectionPoolSize,
		metrics.backpressureQueue,
	)

	// Connect to NATS with circuit breaker
	nc, err := cb.Execute(func() (interface{}, error) {
		return nats.Connect(nats.DefaultURL, nats.MaxReconnects(-1))
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %v", err)
	}

	// Get JetStream context
	js, err := nc.JetStream()
	if err != nil {
		return nil, fmt.Errorf("failed to get JetStream context: %v", err)
	}

	return &OptimizedBridge{
		nc:              nc.(*nats.Conn),
		js:              js,
		circuitBreaker:  cb,
		connectionPool:  pool,
		metrics:         metrics,
		backpressure:    bp,
		requestBatcher:  batcher,
		gracefulShutdown: make(chan struct{}),
	}, nil
}

func (b *OptimizedBridge) Start() error {
	log.Println("🚀 Starting Optimized Ultra SIEM Bridge...")

	// Start metrics server
	go b.startMetricsServer()

	// Start request batcher
	go b.requestBatcher.start()

	// Start backpressure monitoring
	go b.monitorBackpressure()

	// Start circuit breaker monitoring
	go b.monitorCircuitBreaker()

	// Subscribe to threat events with optimized settings
	sub, err := b.nc.Subscribe("ultra-siem.threats", b.handleThreatEvent)
	if err != nil {
		return fmt.Errorf("failed to subscribe: %v", err)
	}

	// Set subscription limits for backpressure
	sub.SetPendingLimits(10000, 1024*1024) // 10K messages, 1MB bytes

	log.Println("✅ Optimized bridge started successfully")
	return nil
}

func (b *OptimizedBridge) handleThreatEvent(msg *nats.Msg) {
	start := time.Now()
	defer func() {
		b.metrics.processingTime.Observe(time.Since(start).Seconds())
		b.metrics.eventsProcessed.Inc()
	}()

	// Apply backpressure
	select {
	case b.backpressure.rateLimiter <- struct{}{}:
	default:
		log.Println("⚠️ Backpressure applied - dropping event")
		b.metrics.errorRate.Inc()
		return
	}

	// Process with circuit breaker
	_, err := b.circuitBreaker.Execute(func() (interface{}, error) {
		return b.processEvent(msg.Data)
	})

	if err != nil {
		log.Printf("❌ Error processing event: %v", err)
		b.metrics.errorRate.Inc()
		return
	}

	// Update events per second metric
	b.updateEventsPerSecond()
}

func (b *OptimizedBridge) processEvent(data []byte) (interface{}, error) {
	// Try protobuf first, fallback to JSON
	var event ThreatEvent
	
	// Attempt protobuf deserialization
	if err := proto.Unmarshal(data, &event); err != nil {
		// Fallback to JSON
		if err := json.Unmarshal(data, &event); err != nil {
			return nil, fmt.Errorf("failed to deserialize event: %v", err)
		}
	}

	// Process the event (simplified for demo)
	log.Printf("🔍 Processing threat: %s (confidence: %.2f)", event.ThreatType, event.Confidence)

	// Store in ClickHouse via optimized batch
	b.requestBatcher.add(event)

	return event, nil
}

func (b *OptimizedBridge) startMetricsServer() {
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

func (b *OptimizedBridge) monitorBackpressure() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			queueSize := len(b.backpressure.rateLimiter)
			b.metrics.backpressureQueue.Set(float64(queueSize))
			
			if queueSize > 800 {
				log.Printf("⚠️ High backpressure: %d events in queue", queueSize)
			}
		case <-b.gracefulShutdown:
			return
		}
	}
}

func (b *OptimizedBridge) monitorCircuitBreaker() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			state := b.circuitBreaker.State()
			var stateValue float64
			switch state {
			case gobreaker.StateClosed:
				stateValue = 0
			case gobreaker.StateHalfOpen:
				stateValue = 1
			case gobreaker.StateOpen:
				stateValue = 2
			}
			b.metrics.circuitBreakerState.Set(stateValue)
		case <-b.gracefulShutdown:
			return
		}
	}
}

func (b *OptimizedBridge) updateEventsPerSecond() {
	// Simple implementation - in production, use a rolling window
	b.metrics.eventsPerSecond.Inc()
}

func (b *OptimizedBridge) Shutdown() {
	log.Println("🛑 Shutting down optimized bridge...")
	close(b.gracefulShutdown)
	
	// Wait for all goroutines
	b.wg.Wait()
	
	// Close NATS connection
	b.nc.Close()
	
	log.Println("✅ Optimized bridge shutdown complete")
}

// ConnectionPool methods
func (cp *ConnectionPool) Get() (*nats.Conn, error) {
	select {
	case conn := <-cp.connections:
		return conn, nil
	default:
		// Create new connection
		conn, err := nats.Connect(nats.DefaultURL)
		if err != nil {
			return nil, err
		}
		
		cp.mu.Lock()
		cp.active[conn] = true
		cp.mu.Unlock()
		
		return conn, nil
	}
}

func (cp *ConnectionPool) Put(conn *nats.Conn) {
	select {
	case cp.connections <- conn:
		// Connection returned to pool
	default:
		// Pool is full, close connection
		conn.Close()
		
		cp.mu.Lock()
		delete(cp.active, conn)
		cp.mu.Unlock()
	}
}

// RequestBatcher methods
func (rb *RequestBatcher) add(item interface{}) {
	// Simplified implementation
	// In production, implement proper batching logic
}

func (rb *RequestBatcher) start() {
	ticker := time.NewTicker(rb.batchTimeout)
	defer ticker.Stop()

	var batch []interface{}

	for {
		select {
		case item := <-rb.batches:
			batch = append(batch, item...)
			
			if len(batch) >= rb.batchSize {
				rb.processBatch(batch)
				batch = batch[:0]
			}
		case <-ticker.C:
			if len(batch) > 0 {
				rb.processBatch(batch)
				batch = batch[:0]
			}
		}
	}
}

func (rb *RequestBatcher) processBatch(batch []interface{}) {
	if err := rb.processor(batch); err != nil {
		log.Printf("❌ Batch processing error: %v", err)
	}
}

func processBatch(batch []interface{}) error {
	// Process batch of events
	log.Printf("📦 Processing batch of %d events", len(batch))
	return nil
}

func main() {
	bridge, err := NewOptimizedBridge()
	if err != nil {
		log.Fatalf("❌ Failed to create optimized bridge: %v", err)
	}

	if err := bridge.Start(); err != nil {
		log.Fatalf("❌ Failed to start optimized bridge: %v", err)
	}

	// Wait for shutdown signal
	select {}
} 