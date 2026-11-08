// SPDX-License-Identifier: Apache-2.0
// Locate malformed UTF-8 and repair it, the way a log or protocol consumer does.
//
// `validate_utf8_detailed` reports the offset of the first malformed sequence
// and how many bytes of it are malformed. Advancing by that length and emitting
// one replacement scalar per malformed sequence is the same recovery rule as
// Rust's `String::from_utf8_lossy` and Python's `errors="replace"`.
import text from "..";
import std;

const REPLACEMENT: i64 = 0xfffd;

// Append `source` to `out`, replacing each malformed sequence with U+FFFD.
// Returns the number of replacements. An incomplete tail counts as one.
fn repair(source: u8[:], out: u8[>..]&) -> i64 {
    var at = 0;
    var replaced = 0;
    while at < source.len {
        let error = text::validate_utf8_detailed(source[at..]);
        if error.offset < 0 { out.append(source[at..]); break; }
        let start = at + error.offset;
        out.append(source[at..start]);
        assert(text::append_utf8(out, REPLACEMENT));
        replaced++;
        // A zero length means the input ended inside a sequence: nothing after
        // it can be recovered, so the tail is one replacement and we stop.
        if error.length == 0 { break; }
        at = start + error.length;
    }
    return replaced;
}

fn show(label: const u8[:], source: u8[:]) {
    let error = text::validate_utf8_detailed(source);
    var fixed: u8[>..] = [];
    let replaced = repair(source, fixed);
    print(label, ": offset ", error.offset, ", length ", error.length,
          ", replacements ", replaced, ", repaired ", fixed);
}

fn main() {
    show("valid", "Hello, 世界!");
    show("stray continuation", "abc\x80def");
    show("overlong", "a\xc0\x80b");
    show("surrogate", "a\xed\xa0\x80b");
    show("above U+10FFFF", "a\xf4\x90\x80\x80b");
    show("bad third byte", "a\xe2\x82\x28b");
    show("truncated tail", "abc\xe2\x82");
    show("two errors", "\x80ok\xff");

    // The recovery rule is pinned, not just printed.
    var fixed: u8[>..] = [];
    assert(repair("abc\x80def", fixed) == 1 && fixed == "abc\xef\xbf\xbddef");
    fixed.clear();
    assert(repair("a\xe2\x82\x28b", fixed) == 1 && fixed == "a\xef\xbf\xbd(b");
    fixed.clear();
    assert(repair("abc\xe2\x82", fixed) == 1 && fixed == "abc\xef\xbf\xbd");
    fixed.clear();
    assert(repair("\x80ok\xff", fixed) == 2 && fixed == "\xef\xbf\xbdok\xef\xbf\xbd");
    fixed.clear();
    assert(repair("Hello, 世界!", fixed) == 0 && fixed == "Hello, 世界!");
}
