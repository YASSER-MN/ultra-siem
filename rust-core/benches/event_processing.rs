use criterion::{black_box, criterion_group, criterion_main, Criterion};
use siem_rust_core::event_processing::EventProcessor;

pub fn event_processing_benchmark(c: &mut Criterion) {
    let mut processor = EventProcessor::new();
    
    c.bench_function("event_processing_simple", |b| {
        b.iter(|| {
            let event = serde_json::json!({
                "timestamp": "2024-01-01T00:00:00Z",
                "source": "nginx",
                "level": "info",
                "message": "GET /api/health 200",
                "ip": "192.168.1.100"
            });
            processor.process_event(black_box(event));
        });
    });
}

criterion_group!(benches, event_processing_benchmark);
criterion_main!(benches); 