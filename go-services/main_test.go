package main

import (
	"encoding/json"
	"testing"
	"time"
)

// TestRingBuffer tests the lock-free ring buffer functionality
func TestRingBuffer(t *testing.T) {
	// Test buffer creation
	buffer := NewRingBuffer(4)
	if buffer == nil {
		t.Fatal("Failed to create ring buffer")
	}

	// Test putting events
	event1 := &ThreatEvent{
		Timestamp:  uint64(time.Now().Unix()),
		SourceIP:   "192.168.1.1",
		ThreatType: "malware",
		Payload:    "test payload",
		Severity:   5,
		Confidence: 0.8,
	}

	success := buffer.Put(event1)
	if !success {
		t.Error("Failed to put event in buffer")
	}

	// Test getting events
	retrieved := buffer.Get()
	if retrieved == nil {
		t.Error("Failed to get event from buffer")
	}

	if retrieved.SourceIP != event1.SourceIP {
		t.Errorf("Expected source IP %s, got %s", event1.SourceIP, retrieved.SourceIP)
	}

	if retrieved.ThreatType != event1.ThreatType {
		t.Errorf("Expected threat type %s, got %s", event1.ThreatType, retrieved.ThreatType)
	}
}

// TestRingBufferFull tests buffer behavior when full
func TestRingBufferFull(t *testing.T) {
	buffer := NewRingBuffer(2) // Small buffer for testing

	// Fill the buffer
	event1 := &ThreatEvent{SourceIP: "1.1.1.1", ThreatType: "test1"}
	event2 := &ThreatEvent{SourceIP: "2.2.2.2", ThreatType: "test2"}
	event3 := &ThreatEvent{SourceIP: "3.3.3.3", ThreatType: "test3"}

	// First two should succeed
	if !buffer.Put(event1) {
		t.Error("Failed to put first event")
	}
	if !buffer.Put(event2) {
		t.Error("Failed to put second event")
	}

	// Third should fail (buffer full)
	if buffer.Put(event3) {
		t.Error("Should not be able to put event when buffer is full")
	}
}

// TestRingBufferEmpty tests buffer behavior when empty
func TestRingBufferEmpty(t *testing.T) {
	buffer := NewRingBuffer(4)

	// Buffer should be empty initially
	// Note: Get() blocks indefinitely when empty, so we test with a timeout
	done := make(chan bool)
	go func() {
		event := buffer.Get()
		if event != nil {
			t.Error("Should not get event from empty buffer")
		}
		done <- true
	}()

	select {
	case <-done:
		// Test completed
	case <-time.After(100 * time.Millisecond):
		// Expected timeout for empty buffer
	}
}

// TestSIEMProcessorCreation tests processor initialization
func TestSIEMProcessorCreation(t *testing.T) {
	// This test would require mock NATS and ClickHouse connections
	// For now, we test the structure creation without actual connections
	processor := &SIEMProcessor{
		ringBuffer: NewRingBuffer(1024),
	}

	if processor.ringBuffer == nil {
		t.Error("Failed to create SIEM processor with ring buffer")
	}
}

// TestThreatEventSerialization tests JSON serialization
func TestThreatEventSerialization(t *testing.T) {
	event := &ThreatEvent{
		Timestamp:  1234567890,
		SourceIP:   "192.168.1.100",
		ThreatType: "sql_injection",
		Payload:    "SELECT * FROM users",
		Severity:   8,
		Confidence: 0.95,
	}

	// Test that the struct can be marshaled to JSON
	_, err := json.Marshal(event)
	if err != nil {
		t.Errorf("Failed to marshal ThreatEvent: %v", err)
	}
}

// TestGetEnv tests environment variable retrieval
func TestGetEnv(t *testing.T) {
	// Test with default value
	value := getEnv("NONEXISTENT_VAR", "default_value")
	if value != "default_value" {
		t.Errorf("Expected default value, got %s", value)
	}

	// Test with existing environment variable
	// Note: This would require setting environment variables in the test
	// For now, we just test the function signature and basic logic
}

// BenchmarkRingBufferPut tests performance of putting events
func BenchmarkRingBufferPut(b *testing.B) {
	buffer := NewRingBuffer(1024)
	event := &ThreatEvent{
		Timestamp:  uint64(time.Now().Unix()),
		SourceIP:   "192.168.1.1",
		ThreatType: "benchmark",
		Payload:    "benchmark payload",
		Severity:   5,
		Confidence: 0.8,
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		buffer.Put(event)
	}
}

// BenchmarkRingBufferGet tests performance of getting events
func BenchmarkRingBufferGet(b *testing.B) {
	buffer := NewRingBuffer(1024)
	event := &ThreatEvent{
		Timestamp:  uint64(time.Now().Unix()),
		SourceIP:   "192.168.1.1",
		ThreatType: "benchmark",
		Payload:    "benchmark payload",
		Severity:   5,
		Confidence: 0.8,
	}

	// Pre-fill buffer
	for i := 0; i < 1000; i++ {
		buffer.Put(event)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		buffer.Get()
	}
}

// TestConcurrentRingBufferAccess tests thread safety
func TestConcurrentRingBufferAccess(t *testing.T) {
	buffer := NewRingBuffer(1000)
	numGoroutines := 10
	numOperations := 100

	// Start multiple goroutines putting events
	done := make(chan bool, numGoroutines)
	for i := 0; i < numGoroutines; i++ {
		go func(id int) {
			for j := 0; j < numOperations; j++ {
				event := &ThreatEvent{
					Timestamp:  uint64(time.Now().Unix()),
					SourceIP:   "192.168.1.1",
					ThreatType: "concurrent_test",
					Payload:    "test payload",
					Severity:   5,
					Confidence: 0.8,
				}
				buffer.Put(event)
			}
			done <- true
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < numGoroutines; i++ {
		<-done
	}

	// Verify we can retrieve events
	eventsRetrieved := 0
	for i := 0; i < numGoroutines*numOperations; i++ {
		event := buffer.Get()
		if event != nil {
			eventsRetrieved++
		}
	}

	// We should have retrieved most events (some might be dropped due to buffer size)
	if eventsRetrieved == 0 {
		t.Error("No events were retrieved from buffer")
	}
} 