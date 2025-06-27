#include <immintrin.h>
#include <stdint.h>
#include <string.h>

// Advanced SIMD pattern scanning using AVX2 (Docker-compatible)
int advanced_simd_scan(const uint8_t* data, size_t len, const uint8_t* pattern, size_t pattern_len) {
    if (len < 32 || pattern_len == 0) {
        // Fallback to standard string search for small data
        const char* result = strstr((const char*)data, (const char*)pattern);
        return result ? (int)(result - (const char*)data) : -1;
    }
    
    if (pattern_len > 32) {
        return -1; // Pattern too long for single vector
    }
    
    // Load pattern into AVX2 register (broadcast first character)
    __m256i pattern_vec = _mm256_set1_epi8(pattern[0]);
    
    // Process 32 bytes at a time
    for (size_t i = 0; i <= len - 32; i += 32) {
        // Load 32 bytes of data
        __m256i data_vec = _mm256_loadu_si256((__m256i*)(data + i));
        
        // Compare with pattern
        __m256i cmp_result = _mm256_cmpeq_epi8(data_vec, pattern_vec);
        uint32_t mask = _mm256_movemask_epi8(cmp_result);
        
        if (mask != 0) {
            // Found potential match, verify with full pattern
            int bit_pos = 0;
            while (mask != 0) {
                if (mask & 1) {
                    size_t pos = i + bit_pos;
                    if (pos + pattern_len <= len && 
                        memcmp(data + pos, pattern, pattern_len) == 0) {
                        return (int)pos;
                    }
                }
                mask >>= 1;
                bit_pos++;
            }
        }
    }
    
    // Check remaining bytes with scalar method
    if (len >= 32) {
        size_t remaining_start = (len / 32) * 32;
        const char* result = strstr((const char*)(data + remaining_start), (const char*)pattern);
        if (result) {
            return (int)(result - (const char*)data);
        }
    }
    
    return -1; // Pattern not found
}

// Additional SIMD utilities for performance optimization
void simd_memcpy_large(void* dest, const void* src, size_t size) {
    uint8_t* d = (uint8_t*)dest;
    const uint8_t* s = (const uint8_t*)src;
    
    // Copy 32 bytes at a time using AVX2
    while (size >= 32) {
        __m256i data = _mm256_loadu_si256((__m256i*)s);
        _mm256_storeu_si256((__m256i*)d, data);
        d += 32;
        s += 32;
        size -= 32;
    }
    
    // Handle remaining bytes
    memcpy(d, s, size);
}

// SIMD-optimized threat scoring
float simd_calculate_threat_score(const uint8_t* payload, size_t len) {
    if (len < 32) {
        return 0.1f; // Low score for small payloads
    }
    
    float score = 0.0f;
    
    // Count suspicious patterns using SIMD
    const char* patterns[] = {
        "<script>", "javascript:", "eval(", "onclick=", 
        "UNION SELECT", "'; DROP", "/**/", "1=1"
    };
    
    for (int i = 0; i < 8; i++) {
        int pos = advanced_simd_scan(payload, len, (const uint8_t*)patterns[i], strlen(patterns[i]));
        if (pos >= 0) {
            score += 0.15f; // Each pattern adds to threat score
        }
    }
    
    // Additional scoring based on payload characteristics
    if (len > 1024) score += 0.1f; // Large payload
    if (len > 4096) score += 0.2f; // Very large payload
    
    return score > 1.0f ? 1.0f : score;
} 