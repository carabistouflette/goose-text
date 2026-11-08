// SPDX-License-Identifier: Apache-2.0
namespace text;
import std;

// Decode exactly one scalar at a byte offset. Failure is (-1, 0), including
// EOF, out-of-range offsets and continuation-byte offsets. Never replaces bytes.
fn decode_utf8(source: u8[:], offset: i64) -> i64, i64 {
    if offset < 0 || offset >= source.len { return -1, 0; }
    let lead = source[offset];
    if lead < 0x80 { return lead, 1; }
    var width = 0;
    var scalar = 0;
    var lo: u8 = 0x80;
    var hi: u8 = 0xbf;
    if lead >= 0xc2 && lead <= 0xdf { width = 2; scalar = lead & 0x1f; }
    else if lead >= 0xe0 && lead <= 0xef {
        width = 3; scalar = lead & 0x0f;
        if lead == 0xe0 { lo = 0xa0; }
        if lead == 0xed { hi = 0x9f; }
    } else if lead >= 0xf0 && lead <= 0xf4 {
        width = 4; scalar = lead & 7;
        if lead == 0xf0 { lo = 0x90; }
        if lead == 0xf4 { hi = 0x8f; }
    } else { return -1, 0; }
    if width > source.len - offset { return -1, 0; }
    let second = source[offset + 1];
    if second < lo || second > hi { return -1, 0; }
    scalar = (scalar << 6) | (second & 0x3f);
    for i in 2..width {
        let byte = source[offset + i];
        if byte < 0x80 || byte > 0xbf { return -1, 0; }
        scalar = (scalar << 6) | (byte & 0x3f);
    }
    return scalar, width;
}

// Return -1 on success, otherwise the start of the first malformed sequence.
fn validate_utf8(source: u8[:]) -> i64 {
    var at = 0;
    while at < source.len {
        if source[at] < 0x80 {
            // Safe byte loads only: no alignment, word casts, padding or overreads.
            // Enter this scan only on ASCII; Unicode needs at most four loads.
            var tail = source[at..];
            while tail.len >= 8 {
                let chunk = tail[..8];
                if (chunk[0] | chunk[1] | chunk[2] | chunk[3] |
                        chunk[4] | chunk[5] | chunk[6] | chunk[7]) >= 0x80 { break; }
                tail = tail[8..];
            }
            at = source.len - tail.len;
            while at < source.len && source[at] < 0x80 { at++; }
            if at == source.len { break; }
        }
        let scalar, width = decode_utf8(source, at);
        if width == 0 { return at; }
        at += width;
    }
    return -1;
}
fn valid_utf8(source: u8[:]) -> bool { validate_utf8(source) == -1 }

// Append one Unicode scalar. Invalid input leaves out unchanged.
fn append_utf8(out: u8[>..]&, scalar: i64) -> bool {
    if scalar < 0 || scalar > 0x10ffff || (scalar >= 0xd800 && scalar <= 0xdfff) { return false; }
    push_utf8(out, scalar);
    return true;
}

// Structured diagnostic for the first malformed sequence. `offset` is -1 when
// the whole input is valid. Otherwise `offset` is the zero-based start of the
// sequence and `length` is how many bytes of it are malformed: 1..3 for a
// malformed prefix, 0 when the input ends inside a sequence.
struct Utf8Error {
    offset: i64 = -1,
    length: i64 = 0,
}

// Return the structured diagnostic for the first malformed sequence.
//
// Calls `validate_utf8` once and inspects at most four bytes, only on failure,
// so the success path is exactly `validate_utf8`'s. `length` matches Rust's
// `Utf8Error::error_len()`: 1..3 is the malformed prefix a caller replaces, 0 is
// Rust's `None`, an input that ended inside a sequence. For every non-truncated
// error it also equals Python's `UnicodeDecodeError.end - start`; for a
// truncated one Python reports `end == len(source)` where this reports 0.
fn validate_utf8_detailed(source: u8[:]) -> Utf8Error {
    let at = validate_utf8(source);
    if at < 0 { return Utf8Error { .. }; }
    let lead = source[at];
    // 0x80..0xc1 and 0xf5..0xff cannot start a sequence: one byte is malformed.
    if lead < 0xc2 || lead > 0xf4 { return Utf8Error { offset: at, length: 1 }; }
    var width = 2;
    var lo: u8 = 0x80;
    var hi: u8 = 0xbf;
    if lead >= 0xe0 { width = 3; }
    if lead >= 0xf0 { width = 4; }
    if lead == 0xe0 { lo = 0xa0; }
    if lead == 0xed { hi = 0x9f; }
    if lead == 0xf0 { lo = 0x90; }
    if lead == 0xf4 { hi = 0x8f; }
    // The first continuation byte carries the overlong, surrogate and
    // above-U+10FFFF bounds; the rest are plain UTF8-tail bytes.
    for i in 1..width {
        // Compare against the remaining length, as `decode_utf8` does, so the
        // end test never forms `at + i`.
        if i >= source.len - at { return Utf8Error { offset: at, length: 0 }; }
        let byte = source[at + i];
        let low:  u8 = if i == 1 { lo } else { 0x80 };
        let high: u8 = if i == 1 { hi } else { 0xbf };
        if byte < low || byte > high { return Utf8Error { offset: at, length: i }; }
    }
    // Unreachable: `validate_utf8` returned this offset, so one check above
    // failed. Kept so the function is total without a second validator.
    return Utf8Error { offset: at, length: 1 };
}
