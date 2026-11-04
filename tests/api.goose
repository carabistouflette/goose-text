// SPDX-License-Identifier: Apache-2.0
import text from "..";
import std;

fn rejected(source: u8[:], offset: i64) {
    assert(!text::valid_utf8(source));
    assert(text::validate_utf8(source) == offset);
    let scalar, width = text::decode_utf8(source, offset);
    assert(scalar == -1 && width == 0);
}
fn main() {
    for source in ["", "ASCII\0\x7f", "é", "日本語", "😀", "\xef\xbb\xbf", "\xef\xbf\xbf", "\xf4\x8f\xbf\xbf"] {
        assert(text::valid_utf8(source) && text::validate_utf8(source) == -1);
        var at = 0;
        var encoded: u8[>..] = [];
        while at < source.len {
            let scalar, width = text::decode_utf8(source, at);
            assert(width > 0 && text::append_utf8(encoded, scalar));
            at += width;
        }
        assert(encoded == source);
    }
    for source in ["\x80", "\xbf", "\xc0\x80", "\xc1\xbf", "\xc2", "\xc2x", "\xe0\x9f\xbf", "\xed\xa0\x80", "\xef\xbf", "\xf0\x8f\xbf\xbf", "\xf4\x90\x80\x80", "\xf5\x80\x80\x80", "\xff"] {
        rejected(source, 0);
        for size in 25 {
            var padded: u8[>..] = [];
            for i in size { padded.push('a'); }
            padded.append(source);
            rejected(padded, size);
        }
    }
    for offset in [-9223372036854775807 - 1, -1, 0, 1, 9223372036854775807] {
        let scalar, width = text::decode_utf8("", offset);
        assert(scalar == -1 && width == 0);
    }
    for offset in [-1, 1, 2, 3, 9223372036854775807] {
        let scalar, width = text::decode_utf8("é", offset);
        assert(scalar == -1 && width == 0);
    }
    for source in ["é", "世", "😀"] {
        var prefixed = str("abc"); prefixed.append(source);
        let scalar, width = text::decode_utf8(prefixed, 3);
        assert(scalar >= 0 && width == source.len);
        for offset in 1..source.len {
            let bad, size = text::decode_utf8(prefixed, 3 + offset);
            assert(bad == -1 && size == 0);
        }
    }
    var out = str("prefix");
    for scalar in [-9223372036854775807 - 1, -1, 0xd800, 0xdfff, 0x110000, 9223372036854775807] {
        assert(!text::append_utf8(out, scalar) && out == "prefix");
    }
    // Exhaust every Unicode code point, including all surrogate rejections.
    for scalar in 0x110000 {
        out.clear();
        let ok = text::append_utf8(out, scalar);
        if scalar >= 0xd800 && scalar <= 0xdfff { assert(!ok && out.len == 0); continue; }
        assert(ok && text::valid_utf8(out));
        let decoded, width = text::decode_utf8(out, 0);
        assert(decoded == scalar && width == out.len);
        for size in 1..out.len { rejected(out[..size], 0); }
    }
    print("UTF-8 public API tests passed");
}
