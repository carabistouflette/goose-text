// SPDX-License-Identifier: Apache-2.0
import text from "..";
import std;
// More specific global overloads must not affect strict text output.
fn push(out: u8[>..]&, value: u8) { assert(false); }
fn push_utf8<T>(out: u8[>..]&, value: T) { assert(false); }
fn valid_utf8(source: u8[:]) -> bool { false }
fn validate_utf8(source: u8[:]) -> i64 { 123 }
fn main() {
    var out: u8[>..] = [];
    assert(text::append_utf8(out, 0x1f600));
    assert(out == "😀" && text::valid_utf8(out));
    assert(text::validate_utf8(out) == -1);
    assert(!text::append_utf8(out, 0xd800) && out == "😀");
    print("Consumer overload isolation passed");
}
