# goose-text

Strict, allocation-free UTF-8 validation and scalar decoding for the
[Goose programming language](https://github.com/aardappel/goose).
Pure Goose, Apache-2.0. Experimental interface; no release yet.

```goose
import text from "carabistouflette/goose-text@09d5f0c39e50d3270189bd0c6798cd10ab2f0c0d";
import std;

fn main() {
    let source = "Hello, 世界!";
    let error = text::validate_utf8(source);
    if error >= 0 { print("Malformed UTF-8 sequence at byte ", error); return; }
    let scalar, width = text::decode_utf8(source, 7);
    print("First Chinese scalar: ", scalar, ", bytes: ", width);
}
```

Declare the package in the application’s root source. The example pins a
reviewed source commit. A nearby checkout can use `import text from "../goose-text";`
instead. The API lives in `namespace text`.

## API contract

| Function | Result |
| --- | --- |
| `validate_utf8(bytes)` | `-1` if valid; otherwise the zero-based start of the first malformed sequence |
| `valid_utf8(bytes)` | Whether the entire byte slice is valid UTF-8 |
| `decode_utf8(bytes, offset)` | `(Unicode scalar, byte width)` for one sequence, or `(-1, 0)` on failure |
| `append_utf8(out, scalar)` | Append one scalar; return false without changing output if invalid |

Validation rejects stray continuations, overlong encodings, surrogates,
truncation and values above U+10FFFF. For `61 E2 28 A1`, the error offset is 1
(the lead byte), rather than 2 (the unexpected continuation). A truncated final
sequence also reports its lead byte. Empty input is valid. NUL, BOM, noncharacters
and U+FFFD are valid scalars; the library neither strips nor replaces them.
It does not impose application-specific text restrictions.

Decoding checks only the sequence at the supplied byte offset, not the prefix or
suffix. Negative offsets, offsets at/past EOF, continuation-byte offsets and
malformed sequences all return `(-1, 0)`. To distinguish EOF, check
`offset == bytes.len` yourself. On success advance by the returned width (1..4);
on failure stop. There is no implicit replacement or resynchronization.

Encoding accepts 0..U+10FFFF excluding U+D800..U+DFFF. After validation, it uses
Goose's standard-library encoder. Rejection is atomic; allocation failure is
governed by Goose's runtime. Output belongs to the caller. No function retains
input references, owns files, reads environment variables or uses global state.

Validation is O(n) time and O(1) extra space with no allocation, safe eight-byte
ASCII scans, no word casts or overreads. Decode takes O(1) time. Append emits at most four bytes; buffer growth costs
follow Goose’s builder/runtime. Input slices have no arbitrary size cap: applications must
bound their input and iteration/output budgets. Scalar counts are neither
user-perceived character counts nor terminal widths. Normalization, case folding,
grapheme segmentation, streaming and replacement decoding are outside v1.

The pinned standard library's `each_utf8` replaces malformed input and its
`push_utf8` permits surrogate encodings for JSON. Use those when those semantics
are intended; this library supplies strict boundary checks.

## Development

```sh
git clone https://github.com/carabistouflette/goose-text.git
cd goose-text
make setup
make format check test
make property security
make sanitize SANITIZER_CC=gcc
make sanitize SANITIZER_CC=clang
make fuzz
make bench
```

Setup builds the full compiler revision in `GOOSE_REVISION`; requirements are
Git, CMake 3.27+, C/C++20 compilers and Make. Tests additionally require Python
3.11+; Linux in-process execution requires libc development headers. An existing
matching compiler can be passed as `GOOSE=/absolute/path/to/goose`.

Public tests run in-process, optimized native and debug native modes with bounds
checks. They exhaust every Unicode scalar and surrogate rejection. The Python
strict codec oracle checks all one/two-byte inputs, deterministic malformed and
valid samples, all Unicode scalars in one document, byte offsets, long inputs,
and encode/decode round trips. ASan/UBSan instrument the generated native code. `make fuzz` runs a bounded
Clang/libFuzzer campaign and first verifies that Goose assertion failures save
the exact triggering input.
These checks do not constitute a proof for all inputs.
The fuzzer requires Clang with libFuzzer, ASan and UBSan. It uses a fixed seed,
a 64 KiB generated-input cap, and run/time limits; logs and crash artifacts stay
under `.build/fuzz/`. See [bench/README.md](bench/README.md)
for reproducible benchmark scope and a recorded run with raw samples. CI checks execution, never timing thresholds.

Tested locally on Linux x86-64 with the pinned compiler, GCC and Clang. The
library has no OS calls or native kernel; other platforms are unverified.
Sanitizer/fuzzer development targets currently assume Linux GCC/Clang.
See [SECURITY.md](SECURITY.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
