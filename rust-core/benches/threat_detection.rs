use criterion::{black_box, criterion_group, criterion_main, Criterion};
use siem_rust_core::threat_detection::ThreatDetector;

pub fn threat_detection_benchmark(c: &mut Criterion) {
    let mut detector = ThreatDetector::new();
    
    c.bench_function("threat_detection_simple", |b| {
        b.iter(|| {
            let event = serde_json::json!({
                "timestamp": "2024-01-01T00:00:00Z",
                "source": "nginx",
                "level": "info",
                "message": "GET /api/health 200",
                "ip": "192.168.1.100"
            });
            detector.detect_threats(black_box(event));
        });
    });
}

criterion_group!(benches, threat_detection_benchmark);
criterion_main!(benches); 