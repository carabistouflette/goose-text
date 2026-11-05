# UTF-8 benchmarks

These measurements time `validate_utf8`, not decoding, encoding or allocations.
The harness checks each expected error offset and a checksum, builds inputs
outside the timed loop, and measures repeated calls on the same bytes. Results
are process-average nanoseconds per validation, not individual-call latencies.
No other library is compared.

## Which results apply?

The [paired raw data](results/2026-11-04-paired-ascii-slices.json) measured
`bb67c7e2fe4e1d8b612a2007833d8fcaa71adbea` against the earlier
`6f31dbc8a7d78f17994c3f586cfbbe053608fdc1` implementation.
At published main `46059e30be79ece6efd4317eb0adc6d213c808ab`, the candidate's
`text.goose`, benchmark harness, recorders, compiler pin and bootstrap script are
byte-identical. The [source bridge and derived summaries](results/source-bridge-46059e3.json)
record their Git blob IDs and SHA-256 hashes, plus the unchanged Makefile
benchmark recipe. Other test targets changed; the whole Makefile is not identical.
This documentation update changes
none of those files, so no new timing run was needed. There are no tagged
releases. Recheck this bridge after code, harness or toolchain changes.

Both recorded builds used Goose `eadca409f68210893f366e60d0c2f0dc29a339be`,
GCC 16.2.1 (20260810) and `goose build -O2`. Goose's `std` and the harness's
`os` module come from that pinned compiler checkout; there are no vendored
dependencies. Hardware was an Intel Core Ultra 7 258V, Linux
7.2.11-arch1-1 x86-64 with glibc 2.44, affinity CPU 0. The machine was shared,
without exclusive isolation. Historical reports contain benchmark-binary hashes,
compiler source pins and C compiler versions, but no compiler-executable digest
or complete host package inventory. The bridge verifies source currentness;
it does not retroactively establish those missing build details.

## Paired results for the unchanged validator

One warmup process per binary was discarded. Fifteen pairs ran in deterministic
shuffled order (seed 20261105), each process doing 3,000 validations per fixture.
Ranges below are the minimum and maximum process averages across all 15 samples;
they are dispersion, not confidence intervals. Ratios divide the two medians,
rather than taking a median of pairwise ratios. Raw totals in the artifact are
nanoseconds for the whole loop; divide by 3,000 for the units below.

| Fixture (input bytes) | Baseline median [min, max], ns | Candidate median [min, max], ns | Candidate / baseline |
| --- | ---: | ---: | ---: |
| ascii (16384) | 5929.8 [5868.0, 6225.0] | 2936.1 [2813.0, 3007.6] | 0.495 |
| mixed (16384) | 24778.0 [24426.3, 26381.8] | 24563.0 [23841.0, 25478.4] | 0.991 |
| emoji (16384) | 18742.4 [18378.4, 19210.1] | 18825.3 [18516.2, 19958.3] | 1.004 |
| ascii_spans (65536) | 31706.0 [31271.9, 32786.3] | 14460.9 [14392.4, 15135.5] | 0.456 |
| invalid_early (16384) | 1.8 [1.7, 2.2] | 1.8 [1.7, 1.9] | 0.998 |
| invalid_late (16384) | 5943.2 [5857.5, 6237.5] | 2889.3 [2815.0, 2958.1] | 0.486 |

Ratios below 1 mean less elapsed time in this run. Emoji was slightly slower;
small differences near 1 are not evidence of a reliable improvement or regression
on this shared host. The ASCII results apply to this build and workload, not
other compilers, hardware or application data.

Fixtures repeat 16 ASCII bytes, `Hello 世界 é!`, four emoji, or 62 ASCII bytes
followed by `é`, respectively. The last two fixtures copy ASCII and replace the
first or last byte with `FF`. `invalid_early` returns at byte zero: its input
length is not the number of bytes processed. The validator uses bounded byte
slices, without word casts or reads beyond the input.

## Reproduce

For a new single-build sample, run `make setup` then
`make bench CC=gcc BENCH_ITERATIONS=1000`. Python 3.11+ is required.
The driver discards one process warmup, keeps seven process samples, and writes
raw totals, medians, source revision/dirty state, benchmark-binary hash, compiler
pin/version, flags, platform and CPU to `.build/benchmark.json`. Affinity selects
one available CPU where supported. CI runs a short execution check; it sets no
performance threshold.

The following rebuilds the two historical implementations with one compiler and
repeats the paired protocol. Run it in a new directory. Use the same C compiler
and flags for both builds; installing a newer compiler changes the comparison's
scope. Builds and timing require an otherwise quiet machine for useful results.

```sh
git clone https://github.com/carabistouflette/goose-text.git text-candidate
git -C text-candidate checkout bb67c7e2fe4e1d8b612a2007833d8fcaa71adbea
cd text-candidate
make setup
export GOOSE="$PWD/.toolchain/goose/build/goose"
git clone https://github.com/carabistouflette/goose-text.git ../text-baseline
git -C ../text-baseline checkout 6f31dbc8a7d78f17994c3f586cfbbe053608fdc1
make -C ../text-baseline bench GOOSE="$GOOSE" CC=gcc BENCH_ITERATIONS=2000
mkdir -p .build
"$GOOSE" build bench/bench.goose --cc gcc -O2 -o .build/bench
python3 scripts/compare-bench.py ../text-baseline/.build/bench .build/bench \
    --iterations 3000 --pairs 15 --cc gcc \
    --baseline-report ../text-baseline/.build/benchmark.json
```

Output is `.build/comparison.json`. The comparison driver checks the baseline
report's binary hash and compiler pin, but cannot verify build flags or C compiler
identity from the binary. Preserve actual build commands and metadata with any
new report. These are warm repeated-input microbenchmarks: they do not measure
cold latency, application throughput or resource limits.

To recheck the source bridge without running timings, from this repository run:

```sh
git diff --exit-code bb67c7e2fe4e1d8b612a2007833d8fcaa71adbea HEAD -- \
    text.goose bench/bench.goose GOOSE_REVISION scripts/setup-goose.sh \
    scripts/benchmark.py scripts/compare-bench.py
```

## Historical unoptimized run

The [original raw data](results/2026-11-04-linux-x86_64.json) measured
`09d5f0c39e50d3270189bd0c6798cd10ab2f0c0d`, before the bounded-slice scan.
It is not a measurement of the current validator. Its relevant source matches
the paired baseline above; the source bridge records that check.
On the same recorded platform/compiler, `make bench BENCH_ITERATIONS=1000 CC=cc`
(with the pinned `GOOSE`) discarded one warmup process and kept seven samples.
Raw totals are divided by 1,000 below. All samples, including slow runs, remain
in the original artifact.

| Fixture | Median [min, max], ns/validation |
| --- | ---: |
| ascii | 6260.2 [6063.2, 12061.6] |
| mixed | 26198.4 [25070.3, 30738.7] |
| emoji | 19508.5 [18838.3, 22237.7] |
| ascii_spans | 33571.0 [32627.7, 38805.7] |
| invalid_early | 2.0 [1.9, 2.1] |
| invalid_late | 6189.3 [5894.8, 6301.3] |
