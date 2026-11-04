// SPDX-License-Identifier: Apache-2.0
import text from "..";
import std;
import os;
fn main() {
    let argv = args();
    var iterations = 1000;
    if argv.len > 1 {
        let count, ok = parse_int(argv[1], 10);
        assert(ok && count > 0 && count <= 10000000);
        iterations = count;
    }
    var ascii: u8[>..] = [];
    var mixed: u8[>..] = [];
    var emoji: u8[>..] = [];
    var spans: u8[>..] = [];
    for i in 1024 {
        ascii.append("abcdefghijklmnop");
        mixed.append("Hello 世界 é!");
        emoji.append("😀🌍🦆🚀");
        spans.append("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789é");
    }
    var early = copy(ascii); early[0] = 0xff;
    var late = copy(ascii); late[late.len - 1] = 0xff;
    let names = ["ascii", "mixed", "emoji", "ascii_spans", "invalid_early", "invalid_late"];
    let inputs: (const u8[:])[6] = [ascii, mixed, emoji, spans, early, late];
    let errors = [-1, -1, -1, -1, 0, late.len - 1];
    var checksum = 0;
    for source, index in inputs {
        assert(text::validate_utf8(source) == errors[index]);
        let start = clock_ns();
        for i in iterations {
            let error = text::validate_utf8(source);
            checksum += error + 2;
        }
        print(names[index], "\t", clock_ns() - start, "\t", iterations, "\t", source.len);
    }
    print("checksum\t", checksum);
}
