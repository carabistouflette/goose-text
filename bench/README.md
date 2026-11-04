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

## Bounded-slice audit run

[Paired raw measurements](results/2026-11-04-paired-ascii-slices.json) compare
baseline `6f31dbc8a7d78f17994c3f586cfbbe053608fdc1` with
`bb67c7e2fe4e1d8b612a2007833d8fcaa71adbea`. Both binaries used the same pinned
Goose compiler and GCC 16.2.1 with `-O2` on the Linux x86-64 machine above.
The candidate tree was clean; the report records its exact library source hash,
both binary hashes, baseline provenance, per-process warmups, CPU affinity,
shuffled pair order and raw samples. Fifteen pairs ran 3,000 validations per
fixture per process. Values below are ratios of warm process medians.

| Fixture | Candidate / baseline time |
| --- | ---: |
| ascii | 0.495 |
| mixed | 0.991 |
| emoji | 1.004 |
| ascii_spans | 0.456 |
| invalid_early | 0.998 |
| invalid_late | 0.486 |

Ratios below 1 indicate less time. This supports retaining the slice-based
ASCII loop on this build; small differences near 1 are within development-machine
noise. It does not establish superiority for other compilers, hardware or data.
The library still uses safe slices, without word casts or unchecked overreads.

To repeat a paired comparison, build the harness at each source revision with
the same Goose compiler, C compiler and flags, preserving each binary. From the
candidate checkout run:

```sh
python3 scripts/compare-bench.py /path/to/baseline /path/to/candidate \
    --iterations 3000 --pairs 15 --baseline-report /path/to/baseline/benchmark.json
```

The optional baseline report is the `.build/benchmark.json` produced by
`make bench` at the baseline revision; the driver verifies its binary hash and
compiler pin before including it. Keep the recorded flags/compiler consistent
with the actual builds. Output defaults to `.build/comparison.json`.
