// SPDX-License-Identifier: Apache-2.0
// Test-only hex-line adapter. Applications own input size limits.
import text from "..";
import std;
import os;
fn nibble(c: u8) -> u8 {
    if c >= '0' && c <= '9' { return c - '0'; }
    assert(c >= 'a' && c <= 'f');
    c - 'a' + 10
}
fn main() {
    var line:    u8[>..] = [];
    var bytes:   u8[>..] = [];
    var encoded: u8[>..] = [];
    loop {
        line.clear();
        if !read_line(line) { break; }
        assert(line.len % 2 == 0);
        bytes.clear(); encoded.clear();
        var i = 0;
        while i < line.len {
            bytes.push(nibble(line[i]) * 16 + nibble(line[i + 1]));
            i += 2;
        }
        let error = text::validate_utf8(bytes);
        assert(text::valid_utf8(bytes) == (error == -1));
        var at = 0;
        var count = 0;
        var sum = 0;
        while at < bytes.len {
            let scalar, width = text::decode_utf8(bytes, at);
            if width == 0 { assert(error == at && scalar == -1); break; }
            assert(text::append_utf8(encoded, scalar));
            sum += scalar;
            count++;
            at += width;
        }
        assert(encoded == bytes[..at]);
        assert((error == -1) == (at == bytes.len));
        print(error, "\t", count, "\t", sum);
    }
}
