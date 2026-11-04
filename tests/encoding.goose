// SPDX-License-Identifier: Apache-2.0
import text from "..";
import std;
import os;
fn main() {
    var out = str("prefix");
    for scalar in [-9223372036854775807 - 1, -1, 0x110000, 9223372036854775807] {
        assert(!text::append_utf8(out, scalar) && out == "prefix");
    }
    for scalar in 0x110000 {
        if scalar >= 0xd800 && scalar <= 0xdfff {
            let before = out.len;
            assert(!text::append_utf8(out, scalar) && out.len == before);
        } else { assert(text::append_utf8(out, scalar)); }
    }
    write_stdout(out);
}
