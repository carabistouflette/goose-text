// SPDX-License-Identifier: Apache-2.0
import text from "..";
import std;
fn main() {
    let source = "Hello, 世界!";
    let error = text::validate_utf8(source);
    if error >= 0 { print("Invalid UTF-8 sequence at byte ", error); return; }
    var at = 0;
    while at < source.len {
        let scalar, width = text::decode_utf8(source, at);
        print("Scalar ", scalar, " occupies ", width, " bytes");
        at += width;
    }
}
