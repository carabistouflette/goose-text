GOOSE ?= .toolchain/goose/build/goose
CC ?= gcc
SANITIZER_CC ?= gcc
BENCH_ITERATIONS ?= 1000
RUST_ORACLE ?=
.NOTPARALLEL:
.PHONY: setup format check test property security sanitize bench
setup:
	./scripts/setup-goose.sh
format:
	"$(GOOSE)" format text.goose tests examples bench
check:
	"$(GOOSE)" format --check text.goose tests examples bench
	"$(GOOSE)" check tests/encoding.goose
	"$(GOOSE)" check tests/overloads.goose
	"$(GOOSE)" check tests/api.goose
	"$(GOOSE)" check tests/oracle.goose
	"$(GOOSE)" check tests/fuzz.goose
	"$(GOOSE)" check tests/diagnostics.goose
	python3 -m py_compile tests/diagnostics-model.py tests/diagnostics-model-check.py
	"$(GOOSE)" check examples/utf8.goose
	"$(GOOSE)" check examples/diagnostics.goose
	"$(GOOSE)" check bench/bench.goose
test:
	mkdir -p .build
	"$(GOOSE)" run tests/overloads.goose
	"$(GOOSE)" build tests/overloads.goose --cc "$(CC)" -O2 -o .build/overloads
	./.build/overloads
	python3 tests/encode-model.py "$(GOOSE)" run tests/encoding.goose
	"$(GOOSE)" run tests/api.goose
	"$(GOOSE)" build tests/api.goose --cc "$(CC)" -O2 -o .build/api
	./.build/api
	"$(GOOSE)" build tests/api.goose --cc "$(CC)" --debug --no-bce -o .build/api-debug
	./.build/api-debug
	"$(GOOSE)" run examples/utf8.goose
	"$(GOOSE)" run examples/diagnostics.goose
property:
	mkdir -p .build
	"$(GOOSE)" build tests/oracle.goose --cc "$(CC)" -O2 -o .build/oracle
	python3 tests/model.py .build/oracle
	python3 tests/decode-model.py .build/oracle
	"$(GOOSE)" build tests/oracle.goose --cc "$(CC)" --debug --no-bce -o .build/oracle-debug
	python3 tests/model.py .build/oracle-debug
	python3 tests/decode-model.py .build/oracle-debug
	"$(GOOSE)" build tests/encoding.goose --cc "$(CC)" -O2 -o .build/encoding
	python3 tests/encode-model.py ./.build/encoding
	"$(GOOSE)" build tests/encoding.goose --cc "$(CC)" --debug --no-bce -o .build/encoding-debug
	python3 tests/encode-model.py ./.build/encoding-debug
	"$(GOOSE)" build tests/diagnostics.goose --cc "$(CC)" -O2 -o .build/diagnostics
	python3 tests/diagnostics-model.py .build/diagnostics $(if $(RUST_ORACLE),--rust $(RUST_ORACLE),)
	python3 tests/diagnostics-model-check.py .build/diagnostics
	"$(GOOSE)" build tests/diagnostics.goose --cc "$(CC)" --debug --no-bce -o .build/diagnostics-debug
	python3 tests/diagnostics-model.py .build/diagnostics-debug $(if $(RUST_ORACLE),--rust $(RUST_ORACLE),)
security: property
sanitize:
	mkdir -p .build
	SANITIZER_CC="$(SANITIZER_CC)" "$(GOOSE)" build tests/api.goose --cc "$(abspath scripts/sanitizer-cc.sh)" --standalone --debug --no-bce -o .build/api-sanitize
	ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 ./.build/api-sanitize
	SANITIZER_CC="$(SANITIZER_CC)" "$(GOOSE)" build tests/oracle.goose --cc "$(abspath scripts/sanitizer-cc.sh)" --standalone -O2 --no-bce -o .build/oracle-sanitize
	ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 python3 tests/model.py .build/oracle-sanitize
	ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 python3 tests/decode-model.py .build/oracle-sanitize
	SANITIZER_CC="$(SANITIZER_CC)" "$(GOOSE)" build tests/encoding.goose --cc "$(abspath scripts/sanitizer-cc.sh)" --standalone -O2 --no-bce -o .build/encoding-sanitize
	ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 python3 tests/encode-model.py ./.build/encoding-sanitize
	SANITIZER_CC="$(SANITIZER_CC)" "$(GOOSE)" build tests/diagnostics.goose --cc "$(abspath scripts/sanitizer-cc.sh)" --standalone -O2 --no-bce -o .build/diagnostics-sanitize
	ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 python3 tests/diagnostics-model.py .build/diagnostics-sanitize
bench:
	mkdir -p .build
	"$(GOOSE)" build bench/bench.goose --cc "$(CC)" -O2 -o .build/bench
	BENCH_CC="$(CC)" python3 scripts/benchmark.py .build/bench $(BENCH_ITERATIONS)

FUZZ_SECONDS ?= 30
FUZZ_RUNS ?= 100000
FUZZ_SEED ?= 20261104
FUZZ_CC ?= clang
.PHONY: fuzz
fuzz:
	python3 scripts/fuzz.py --goose "$(GOOSE)" --cc "$(FUZZ_CC)" --seconds "$(FUZZ_SECONDS)" --runs "$(FUZZ_RUNS)" --seed "$(FUZZ_SEED)"

.PHONY: guard
guard:
	mkdir -p .build/guard
	"$(GOOSE)" tests/fuzz.goose --standalone -O2 --header .build/guard/parser-fuzz.h -o .build/guard/text.c
	"$(CC)" -O2 -o .build/guard/test .build/guard/text.c tests/guard.c -I.build/guard -lm -ldl -lpthread
	./.build/guard/test

.PHONY: mutation
mutation:
	python3 scripts/mutation-test.py --goose "$(GOOSE)" --cc "$(CC)"
