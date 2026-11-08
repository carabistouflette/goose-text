# Validation history

These are historical test results, not checks rerun on every documentation commit.
The production source at published `46059e30be79ece6efd4317eb0adc6d213c808ab`
is byte-identical to the implementation tested below; see the
[checked source bridge](../bench/results/source-bridge-46059e3.json).
For commands and prerequisites, see [development](development.md).

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
measurements and recorded source, benchmark-binary and compiler-pin metadata.
Longer inputs and all Unicode scalar values are also covered by deterministic tests independently of
the fuzz campaign. Applications must still enforce their own input/output/work
budgets; this library does not normalize text or impose application syntax rules.

## Independent encoder and test-effectiveness follow-up

A further audit on 2026-11-04 left `text.goose` byte-identical to the bounded-slice
source above. New exact-encoding tests build a single growing output containing
all 1,112,064 valid Unicode scalars and compare every byte with Python's strict
encoder, without using Goose decoding. The stream includes an existing prefix;
all surrogate rejections occur against nonempty output. Invalid extreme values
are checked before the stream. This passed in-process, optimized native,
bounds-checked debug native, and GCC/Clang ASan/UBSan execution.

Consumer-defined `push`, generic `push_utf8` and global validation overloads
could not intercept the namespaced API or built-in byte writes. The pinned
compiler resolves array built-ins before free-function overloads. The regression
fixture passed in-process and optimized native execution.

`make mutation` also passed the unmodified API, validation, arbitrary-offset and
exact-encoding controls, then detected all eleven selected deliberate mistakes:
missing eighth-byte checks, overlong leads, surrogate decoding, above-Unicode
values, invalid later continuations, wrong error offsets, rejecting valid suffixes
after invalid prefixes, mutation before failed encoding, surrogate encoding,
truncation off-by-one, and a paired ASCII encoder/decoder permutation.

Each mutant must compile before it is tested. A test mismatch or an executed
assertion/bounds failure is required; compiler errors, survivors and unexpected
infrastructure failures fail the harness. The paired permutation is tested with
the independent exact-encoding suite because inverse codec mistakes can cancel
in round trips. The harness retains source hash, compiler version, results and
logs under `.build/mutation/`. These representative mutations demonstrate
specific detection paths; they are not an exhaustive mutation-coverage metric.
Two independent reviews found no further blocker. Production code remained
unchanged; the benchmark source bridge describes which measurements still apply.

## Structured diagnostics (2026-11-08)

`validate_utf8_detailed` was added on branch `feat/utf8-detailed-diagnostics`
from published `2e0081bd24be3f0e913bd709a642e955c43f61cb`. `validate_utf8`,
`valid_utf8`, `decode_utf8` and `append_utf8` are byte-identical to that commit;
the new function calls `validate_utf8` once and inspects at most four bytes, only
on failure.

The contract was fixed from primary sources before implementation, not assumed:
Rust's `library/core/src/str/validations.rs` `run_utf8_validation` (the
`err!(Some(1))`/`Some(2)`/`Some(3)`/`None` sites) and Python's
`UnicodeDecodeError.start`/`end`/`reason`. Both agree on every case tested:
`length` is `1..3` for a malformed prefix and `0` for an input that ends inside a
sequence. For a truncated input Python reports `end == len(bytes)` where this
reports `0`; that difference is documented in the README.

Commands executed, each with its real exit status captured from `make` (output
kept under `.build/logs/`):

```sh
make format check test property RUST_ORACLE=/tmp/utf8oracle/target/release/utf8oracle   # exit 0
make guard CC=gcc                                                                        # exit 0
make guard CC=clang                                                                      # exit 0
make sanitize SANITIZER_CC=gcc                                                           # exit 0
make sanitize SANITIZER_CC=clang                                                         # exit 0
make mutation                                                                            # exit 0
make fuzz FUZZ_SECONDS=45 FUZZ_RUNS=200000 FUZZ_CC=clang                                 # exit 0
```

The shared pinned compiler `eadca409f68210893f366e60d0c2f0dc29a339be`
(binary sha256 `3cad45a1…`) was reused; no compiler was rebuilt.

The original `tests/diagnostics-model.py` campaign compared 23,610 inputs with
Python and a locally built Rust `std::str::Utf8Error::error_len()` oracle in
optimized and bounds-checked debug builds. Its GCC/Clang ASan/UBSan runs used
the Python oracle only: those commands did not pass `RUST_ORACLE`. The retained
Rust source enables fresh reproduction; its binary identity is not established
as identical to that original local Cargo helper. The corpus covers every single byte, every two-byte
pair around the interesting leads, three- and four-byte combinations, valid
prefixes of length 0..24 before each malformed class, and 20,000 seeded random
inputs.

The consumer example `examples/diagnostics.goose` repairs malformed input by
advancing by `length` and emitting one U+FFFD per malformed sequence. Its output
and replacement counts match Python's `errors="replace"` on all eight
demonstrated inputs, including `a\xc0\x80b` (two replacements, because `0xc0` is
an invalid lead and `0x80` a stray continuation) and `a\xf4\x90\x80\x80b` (four).

The original mutation campaign detected sixteen mutants. Five targeted the new function: an
illegal lead reported as truncation, truncation reported as replaceable, a length
fixed at one, a dropped surrogate bound, and a dropped first-continuation bound.
The first run of the surrogate mutant **survived**, which exposed a real gap: the
total-function fall-through returns `length: 1`, so a dropped bound is
unobservable unless a later byte is also bad. The API suite now pins
`\xe0\x9f\x28`, `\xed\xa0\x28`, `\xf0\x8f\x28` and `\xf4\x90\x28` (all length 1,
confirmed against both oracles), and the mutant is detected. Two pre-existing
mutant anchors were made indentation-specific because the new function repeats
their text. The retained list now also removes the `0xe0`, `0xf0` and `0xf4`
diagnostic bounds separately, for nineteen mutants total. These extend the list;
the API regression cases already detect all four bound removals.

The fuzz campaign ran 200,000 instrumented executions in 9 seconds with seed
20261104, coverage 260 edges, no failure. `tests/fuzz.goose` now also asserts
that the detailed offset equals the plain one, that `length` stays in `0..3`,
that a malformed prefix still fails when the input is truncated right after it,
that a zero length implies a valid lead with 1..3 bytes present, and that the
repair loop terminates and always yields valid UTF-8.

Limits of this evidence: no external implementation was benchmarked, so no
performance claim is made for the new function. Existing entry points are
unchanged; the new entry point calls `validate_utf8`, checks its result and
inspects at most four bytes on failure. The initial Rust oracle was a local helper;
source for a fresh oracle is now retained in `tests/diagnostics_oracle.rs` for reproduction without
Cargo dependencies. The repository does not vendor a Rust toolchain. The
original CI ran Python alone; the review follow-up builds the retained source
with the runner's Rust compiler and explicitly passes it to CI property and
sanitizer checks. Local commands still default to Python alone.

### Oracle failure-control correction

Coordinator review found that the initial Python runner printed up to twenty
mismatches but still returned success. A proxy changing only the empty-input
diagnostic reproduced this: the original runner exited 0, while the corrected
runner exits 1. The runner now fails on any mismatch and the property target
includes that negative control. Earlier positive logs are superseded by the
coordinator's rerun with the corrected runner; no library API changed in this
test correction.

### Evidence identities

The original `.build/logs/final-*` files describe `f754ffe`, before the runner
failure-control fix in `630f281`. The production module, API/fuzz tests and
mutation script were byte-identical across those two commits, so their original
coverage applies to those files. They do not validate the later runner changes.
The two coordinator `/tmp` follow-up logs did not retain explicit command/exit
records. Fresh review-follow-up logs capture each command and exit separately;
they do not retroactively supply missing records for the old runs.

Pass `RUST_ORACLE` explicitly to `make property` or `make sanitize` to include
the retained Rust oracle. An omitted value means Python-only diagnostics checks.

The review follow-up also rejects adapter stderr (including a recoverable
sanitizer diagnostic), propagates proxy stderr, checks the single-mismatch
message as a complete line and removes an unused Rust helper. Its negative
controls cover a wrong result, stderr with exit zero and a nonzero adapter exit.
