use criterion::{black_box, criterion_group, criterion_main, Criterion};
use siem_rust_core::pattern_matcher::PatternMatcher;

pub fn pattern_matching_benchmark(c: &mut Criterion) {
    let matcher = PatternMatcher::new();
    
    c.bench_function("pattern_matching_simple", |b| {
        b.iter(|| {
            let text = "GET /admin/login.php?user=admin&pass=password";
            matcher.match_patterns(black_box(text));
        });
    });
}

criterion_group!(benches, pattern_matching_benchmark);
criterion_main!(benches); 