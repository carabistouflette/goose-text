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

## Recorded run

[Raw samples and provenance](results/2026-11-04-linux-x86_64.json) were recorded
on 2026-11-04 at source `09d5f0c39e50d3270189bd0c6798cd10ab2f0c0d` with a clean working tree.
Machine: Intel Core Ultra 7 258V, Linux x86-64, GCC 16.2.1, `-O2`, Goose
`eadca409f68210893f366e60d0c2f0dc29a339be`. Command:
`make bench BENCH_ITERATIONS=1000 CC=cc` (using the matching compiler via GOOSE).
One warmup process, seven measured processes, CPU affinity 0. Other processes
were running on this development machine; timings are illustrative and noisy.

| Fixture | Input bytes | Median ns/validation |
| --- | ---: | ---: |
| ascii | 16384 | 6260.2 |
| mixed | 16384 | 26198.4 |
| emoji | 16384 | 19508.5 |
| ascii_spans | 65536 | 33571.0 |
| invalid_early | 16384 | 2.0 |
| invalid_late | 16384 | 6189.3 |

`invalid_early` returns at byte zero; its timing does not represent processing
16 KiB. No cross-library or universal performance claim is made.
