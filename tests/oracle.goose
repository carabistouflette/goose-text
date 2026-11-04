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
fn unhex(input: u8[:], out: u8[>..]&) {
    assert(input.len % 2 == 0);
    out.clear();
    var i = 0;
    while i < input.len {
        out.push(nibble(input[i]) * 16 + nibble(input[i + 1]));
        i += 2;
    }
}
fn main() {
    var line:    u8[>..] = [];
    var bytes:   u8[>..] = [];
    var encoded: u8[>..] = [];
    loop {
        line.clear();
        if !read_line(line) { break; }
        assert(line.len >= 2 && line[1] == '\t');
        if line[0] == 'D' {
            let separator = find(line[2..], "\t") + 2;
            assert(separator > 2);
            let offset, ok = parse_int(line[2..separator], 10);
            assert(ok);
            unhex(line[separator + 1..], bytes);
            let scalar, width = text::decode_utf8(bytes, offset);
            print(scalar, "\t", width);
            continue;
        }
        assert(line[0] == 'V');
        unhex(line[2..], bytes);
        encoded.clear();
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
