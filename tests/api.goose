// SPDX-License-Identifier: Apache-2.0
import text from "..";
import std;

fn rejected(source: u8[:], offset: i64) {
    assert(!text::valid_utf8(source));
    assert(text::validate_utf8(source) == offset);
    let scalar, width = text::decode_utf8(source, offset);
    assert(scalar == -1 && width == 0);
}
// The detailed diagnostic must agree with the plain one on the offset, and
// report the malformed prefix length or 0 for an incomplete sequence.
fn detailed(source: u8[:], offset: i64, length: i64) {
    let error = text::validate_utf8_detailed(source);
    assert(error.offset == text::validate_utf8(source));
    assert(error.offset == offset && error.length == length);
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
    // Structured diagnostics: every malformed class, at every byte position.
    for source in ["", "ASCII\0\x7f", "é", "日本語", "😀", "\xef\xbb\xbf", "\xf4\x8f\xbf\xbf"] {
        detailed(source, -1, 0);
    }
    // Illegal lead bytes: 0x80..0xc1 and 0xf5..0xff. One byte is malformed.
    for source in ["\x80", "\xbf", "\xc0\x80", "\xc1\xbf", "\xf5\x80\x80\x80", "\xff"] {
        detailed(source, 0, 1);
    }
    // Overlong, surrogate and above-U+10FFFF: the first continuation byte fails.
    for source in ["\xe0\x9f\xbf", "\xed\xa0\x80", "\xf0\x8f\xbf\xbf", "\xf4\x90\x80\x80"] {
        detailed(source, 0, 1);
    }
    // The same bounds with a bad later byte: the malformed prefix is still the
    // lead plus the first continuation byte, so the length stays 1. Without
    // these, a dropped bound is masked by the total-function fall-through.
    for source in ["\xe0\x9f\x28", "\xed\xa0\x28", "\xf0\x8f\x28", "\xf4\x90\x28"] {
        detailed(source, 0, 1);
    }
    // A continuation byte out of place at the second, third or fourth byte.
    detailed("\xc2x", 0, 1);
    detailed("\xe2\x28\xa1", 0, 1);
    detailed("\xe2\x82\x28", 0, 2);
    detailed("\xf0\x9f\x98\x28", 0, 3);
    // Truncation: the input ends inside a sequence, so nothing is replaceable.
    for source in ["\xc2", "\xe2\x82", "\xef\xbf", "\xf0\x9f\x98"] {
        detailed(source, 0, 0);
    }
    // The offset is the lead byte, so a valid prefix shifts it and nothing else.
    let shifted = ["\x80", "\xe2\x82\x28", "\xf0\x9f\x98\x28", "\xe2\x82"];
    let shifted_lengths = [1, 2, 3, 0];
    for source, index in shifted {
        for size in 25 {
            var padded: u8[>..] = [];
            for i in size { padded.push('a'); }
            padded.append(source);
            detailed(padded, size, shifted_lengths[index]);
        }
    }
    // ASCII run boundaries around the eight-byte probe.
    for size in [7, 8, 15, 16, 17, 31, 32] {
        var run: u8[>..] = [];
        for i in size { run.push('a'); }
        run.push(0xff);
        detailed(run, size, 1);
        run[run.len - 1] = 0xe2;
        detailed(run, size, 0);
        run.push(0x82);
        detailed(run, size, 0);
        run.push(0x28);
        detailed(run, size, 2);
    }
    print("UTF-8 public API tests passed");
}
