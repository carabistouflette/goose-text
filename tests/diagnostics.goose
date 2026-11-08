// SPDX-License-Identifier: Apache-2.0
// Test-only hex-line adapter for the structured diagnostic. Applications own
// input size limits.
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
    var line:  u8[>..] = [];
    var bytes: u8[>..] = [];
    loop {
        line.clear();
        if !read_line(line) { break; }
        assert(line.len >= 2 && line[1] == '\t');
        assert(line[0] == 'E');
        unhex(line[2..], bytes);
        let error = text::validate_utf8_detailed(bytes);
        // The detailed offset must never disagree with the plain validator.
        assert(error.offset == text::validate_utf8(bytes));
        print(error.offset, "\t", error.length);
    }
}
