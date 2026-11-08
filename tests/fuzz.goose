// SPDX-License-Identifier: Apache-2.0
import text from "..";
import std;
// The recovery rule of examples/diagnostics.goose: one replacement per malformed
// sequence, advancing by the reported length, stopping on an incomplete tail.
fn repair(source: const u8[:], out: u8[>..]&) -> i64 {
    var at = 0;
    var replaced = 0;
    while at < source.len {
        let error = text::validate_utf8_detailed(source[at..]);
        if error.offset < 0 { out.append(source[at..]); break; }
        let start = at + error.offset;
        out.append(source[at..start]);
        assert(text::append_utf8(out, 0xfffd));
        replaced++;
        if error.length == 0 { break; }
        at = start + error.length;
    }
    return replaced;
}
export fn fuzz_parse(source: const u8[:]) -> i64 {
    let error = text::validate_utf8(source);
    assert(text::valid_utf8(source) == (error == -1));
    // The detailed diagnostic must agree on the offset and stay in its domain.
    let detail = text::validate_utf8_detailed(source);
    assert(detail.offset == error);
    assert(detail.length >= 0 && detail.length <= 3);
    if (error == -1) {
        assert(detail.length == 0);
    } else if (detail.length == 0) {
        // Incomplete tail: a valid lead with 1..3 bytes present.
        assert(source.len - error >= 1 && source.len - error <= 3);
        assert(source[error] >= 0xc2 && source[error] <= 0xf4);
    } else {
        // A malformed prefix: it lies inside the input and still fails there.
        assert(detail.length <= source.len - error);
        assert(text::validate_utf8(source[..error + detail.length]) == error);
    }
    // Recovery must terminate and always produce valid UTF-8.
    var fixed: u8[>..] = [];
    let replaced = repair(source, fixed);
    assert(text::valid_utf8(fixed));
    assert(replaced >= 0 && replaced <= source.len);
    var at = 0;
    while at < source.len {
        let scalar, width = text::decode_utf8(source, at);
        if width == 0 { assert(error == at && scalar == -1); return error; }
        assert(width >= 1 && width <= 4 && width <= source.len - at);
        var encoded: u8[>..] = [];
        assert(text::append_utf8(encoded, scalar));
        assert(encoded == source[at..at + width]);
        for i in 1..width {
            let bad, zero = text::decode_utf8(source, at + i);
            assert(bad == -1 && zero == 0);
        }
        at += width;
    }
    assert(error == -1);
    return error;
}
export fn fuzz_assertion_probe(value: i64) { assert(value != 0); }
fn main() {}
