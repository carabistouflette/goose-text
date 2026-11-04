// SPDX-License-Identifier: Apache-2.0
import text from "..";
import std;
export fn fuzz_parse(source: const u8[:]) -> i64 {
    let error = text::validate_utf8(source);
    assert(text::valid_utf8(source) == (error == -1));
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
