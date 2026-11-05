# goose-text

UTF-8 validation, decoding and encoding for the
[Goose programming language](https://github.com/aardappel/goose).
Use it to reject malformed bytes, decode one Unicode scalar, or append a scalar
to a byte buffer. Validation and decoding allocate no memory.

Apache-2.0. The API is experimental: there are no tagged releases yet.
The examples below pin published commit
`46059e30be79ece6efd4317eb0adc6d213c808ab`. Later `main` commits may differ.

## Quickstart

Requires Git, Make, CMake 3.27+ and a C compiler and a C++20 compiler. Setup builds the Goose
compiler pinned in [GOOSE_REVISION](GOOSE_REVISION).

```sh
git clone https://github.com/carabistouflette/goose-text.git
cd goose-text
git checkout 46059e30be79ece6efd4317eb0adc6d213c808ab
make setup
.toolchain/goose/build/goose run examples/utf8.goose
```

The example prints each scalar and its byte width. To use the library in your
own application, save this as `app.goose` and run `goose run app.goose` with that
compiler on your `PATH`:

```goose
import text from "carabistouflette/goose-text@46059e30be79ece6efd4317eb0adc6d213c808ab";
import std;

fn main() {
    let source = "Hello, 世界!";
    let error = text::validate_utf8(source);
    if error >= 0 { print("Invalid UTF-8 sequence at byte ", error); return; }
    let scalar, width = text::decode_utf8(source, 7);
    print("First Chinese scalar: ", scalar, ", bytes: ", width);
}
```

Declare the package import in the application's root source. For a sibling local
checkout, use `import text from "../goose-text";` instead.

## API and limits

| Function | Result |
| --- | --- |
| `validate_utf8(bytes)` | `-1` if valid; otherwise the zero-based start of the first malformed sequence |
| `valid_utf8(bytes)` | Whether the entire byte slice is valid UTF-8 |
| `decode_utf8(bytes, offset)` | `(Unicode scalar, byte width)` for one sequence, or `(-1, 0)` on failure |
| `append_utf8(out, scalar)` | Append one scalar; return false without changing output if invalid |

Inputs are `u8[:]` byte slices; offsets and scalars are `i64`. `out` is a
caller-owned growable byte buffer (`u8[>..]&`).

Validation rejects stray continuation bytes, overlong encodings, surrogates,
truncation and values above U+10FFFF. For `61 E2 28 A1`, it reports offset 1:
the malformed sequence's lead byte. Truncation also reports the lead byte.
Empty input is valid. NUL, BOM, noncharacters and U+FFFD are accepted; they are
neither stripped nor replaced.

Decoding checks only the sequence at the supplied byte offset. It can succeed
after an invalid prefix or before an invalid suffix. Negative offsets, EOF,
offsets beyond EOF, continuation-byte offsets and malformed sequences return
`(-1, 0)`. Check `offset == bytes.len` to distinguish EOF. Advance by the returned
width (1..4) on success; stop on failure. There is no automatic resynchronization.

Encoding accepts 0..U+10FFFF excluding U+D800..U+DFFF. It validates the scalar
before calling Goose's standard-library encoder. Invalid scalars leave output
unchanged. Output belongs to the caller; allocation failures follow Goose's
runtime behavior. No function retains input references or performs I/O.

Validation takes O(n) time and O(1) extra space; decoding takes O(1) time.
Appending emits at most four bytes, plus any buffer growth. There is no library
input-size cap: callers must bound input, output and total work. Scalar counts
are not grapheme counts or terminal widths. The library does not provide
normalization, case folding, grapheme segmentation, streaming or replacement
decoding. Unlike this API, the pinned standard library's `each_utf8` replaces
malformed input and `push_utf8` permits surrogate encodings for JSON.

## Support and development

Validated on Linux x86-64 with the pinned Goose compiler, GCC and Clang; CI runs
on Ubuntu 24.04. The library is pure Goose and makes no OS calls. Other platforms
and compiler revisions have not been verified. Tests need Python 3.11+;
sanitizer, guard-page and fuzz targets currently require Linux development tools.

Run `make check test` after setup. See [development commands](docs/development.md),
[validation history](docs/validation.md) and [benchmark scope and results](bench/README.md)
for details. CI checks benchmark execution, without timing thresholds.
See [contributing](CONTRIBUTING.md), [security reporting](SECURITY.md),
[LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md).
