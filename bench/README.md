# UTF-8 benchmarks

Run `make bench BENCH_ITERATIONS=1000`. The optimized native harness validates
ASCII, mixed scripts, emoji, repeated ASCII spans interrupted by Unicode, and
early/late malformed sequences. Every fixture verifies its expected offset and
feeds a checksum. Inputs are prepared outside the timed loops.

The Python driver pins one available CPU where supported, discards one process
warmup, and records seven process samples in `.build/benchmark.json`, including
raw nanoseconds, bytes, compiler pin, C compiler/version, flags, source revision,
dirty state, CPU and platform. These are warm validation microbenchmarks, not
cold latency, allocation measurements or universal rankings. Tiny invalid-prefix
cases measure early rejection rather than whole-input throughput. CI checks
successful execution without timing thresholds.
