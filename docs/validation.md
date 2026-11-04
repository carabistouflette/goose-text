# UTF-8 audit validation

The 2026-11-04 follow-up audit tested library source
`bb67c7e2fe4e1d8b612a2007833d8fcaa71adbea` on Linux x86-64 with pinned Goose
`eadca409f68210893f366e60d0c2f0dc29a339be` and GCC/Clang.
Two fresh independent reviews checked bounds/progress, strict Unicode ranges,
encoding failure atomicity, native guard tests, oracle independence and the
measured optimization. No confirmed codec bug or security blocker was found.
This is evidence for the tested revision and environments, not a proof for all
inputs or a vulnerability-free guarantee.

Commands executed successfully:

```sh
make format check test property
make guard CC=gcc
make guard CC=clang
make sanitize SANITIZER_CC=gcc
make sanitize SANITIZER_CC=clang
make fuzz FUZZ_SECONDS=60 FUZZ_RUNS=1000000
```

An existing matching compiler was supplied through `GOOSE`. The public API
suite exhausts every Unicode scalar and surrogate rejection in Goose in-process,
optimized native and bounds-checked debug native execution. The strict Python
codec model passed 96,458 documents; the independent incremental decoder model
passed 618,629 exact scalar/width queries, including invalid prefixes, valid
suffixes, continuation offsets, truncated tails, EOF and extreme offsets.
Both models also passed instrumented ASan/UBSan builds under GCC and Clang.

The native guard test places slices against inaccessible pages at both ends and
marks source storage read-only during every call. It checks lengths 0..256,
each malformed-byte position, empty/null slices and full/truncated scalar tails.
It is intended to catch generated-native-code reads beyond the provided memory
and unexpected writes that ordinary spare-capacity buffers could hide.

The final fuzz campaign completed 795,191 instrumented executions in 61 seconds
with seed 20261104, with no failure. The time budget stopped it before the
one-million execution ceiling. Its assertion-bridge self-test verified exact
crash-artifact capture. The generated-input cap was 65,536 bytes; the observed
mutated-size growth does not imply every size up to that cap was exercised.

[Benchmark records](../bench/README.md) retain all fixtures, shuffled paired
measurements and exact source/binary/compiler metadata. Longer inputs and all
Unicode scalar values are also covered by deterministic tests independently of
the fuzz campaign. Applications must still enforce their own input/output/work
budgets; this library does not normalize text or impose application syntax rules.
