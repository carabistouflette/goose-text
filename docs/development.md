# Development

From a repository checkout, `make setup` builds the full compiler revision in
[GOOSE_REVISION](../GOOSE_REVISION). It needs Git, Make, CMake 3.27+, C/C++20
compilers and, on Linux, libc development headers. Tests need Python 3.11+.
To use an existing compiler at that exact revision, pass
`GOOSE=/absolute/path/to/goose` to each Make command.

```sh
make setup
make format check test
make property
```

`check` formats nothing: it checks formatting and typechecks tests, the examples
and benchmark. `test` runs API, encoding and consumer-overload checks in Goose
and native modes, including a bounds-checked debug build, and runs both examples.
`property` compares validation, arbitrary-offset decoding, exact encoding and the
structured diagnostic with Python's strict codecs. `security` is an alias for
`property`.

`tests/diagnostics-model.py` drives `tests/diagnostics.goose` over a
deterministic corpus and compares `validate_utf8_detailed` with Python's
`UnicodeDecodeError`. Pass `RUST_ORACLE=/path/to/binary` to also compare with
Rust's `std::str::Utf8Error::error_len()`; the binary reads one hex input per
line and prints `offset<TAB>length`, with `0` for `None`. The Rust oracle is
optional because the repository does not vendor a Rust toolchain.

Its source is retained in `tests/diagnostics_oracle.rs`. With an existing Rust
compiler, reproduce the optional comparison without downloading any crates:

```sh
mkdir -p .build
make rust-oracle
make property RUST_ORACLE="$PWD/.build/diagnostics-rust"
make sanitize RUST_ORACLE="$PWD/.build/diagnostics-rust"
```

Local commands keep Rust optional. CI builds this helper with its installed
Rust compiler and uses it alongside Python in property and sanitizer checks.

The Python oracle rejects any mismatch, even a single one.
`tests/diagnostics-model-check.py` verifies that behavior using a proxy which
changes exactly one result from the real Goose adapter.

For changes to validation, decoding, encoding or the compiler pin, also run:

```sh
make mutation
make sanitize SANITIZER_CC=gcc
make sanitize SANITIZER_CC=clang
make guard CC=gcc
make guard CC=clang
make fuzz FUZZ_SECONDS=60 FUZZ_RUNS=1000000
```

Sanitizers check generated native code with ASan/UBSan. The Linux guard-page
test places read-only input against inaccessible pages at both ends, including
empty slices and complete/truncated scalar tails. These are development targets;
the library itself has no native component.

The fuzzer requires Clang with libFuzzer, ASan and UBSan. It first checks that a
Goose assertion failure saves the triggering bytes, then uses a fixed seed,
a 64 KiB input cap and both time/run ceilings. Logs and crashes stay in
`.build/fuzz/`. The default `make fuzz` limits are 30 seconds and 100,000 runs;
the longer command above stops at whichever ceiling is reached first.

`make mutation` checks nineteen selected codec and diagnostic mistakes. Unmodified controls must
pass; every mutant must compile, then fail an executed test. Compiler failures
do not count as detection. Generated sources and logs stay in `.build/mutation/`.
These checks demonstrate specific test behavior, not coverage of every bug.

[Validation history](validation.md) describes past runs and their limits.
[Benchmark instructions](../bench/README.md) describe workloads and reproduction.
Do not commit `.build/`, `.toolchain/`, credentials or local working notes.
