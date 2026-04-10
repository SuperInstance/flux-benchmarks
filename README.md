# flux-benchmarks

Real performance benchmarks for the FLUX bytecode runtime ecosystem.

## Latest Results (April 10, 2026)

**Platform**: Oracle Cloud ARM64 (Ampere Altra, 4 cores, 24GB)

### Raw Performance (100K iterations)

| Runtime | Factorial ns/iter | Speed vs C |
|---------|-------------------|------------|
| Native C | 20 | 1.0x |
| Native Rust | 20 | 1.0x |
| **FLUX C VM** | **403** | **0.05x** |
| Python | 1,885 | 0.01x |
| FLUX Python VM | ~141,000 | 0.0001x |

**FLUX C VM is 4.7x faster than CPython for tight arithmetic.**

### Agent Token Efficiency

| Language | Tokens to write factorial(10) |
|----------|------|
| **FLUX Assembly** | **~20** |
| Python | ~25 |
| C | ~50 |
| WASM text | ~80 |

See [BENCHMARK_REPORT.md](BENCHMARK_REPORT.md) for full analysis.
