// SPDX-License-Identifier: Apache-2.0
// Optional test oracle using Rust's standard-library UTF-8 diagnostics.
use std::io::{self, BufRead, Write};

fn main() {
    let stdin = io::stdin();
    let mut out = io::BufWriter::new(io::stdout());
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let line = line.trim();
        let bytes: Vec<u8> = (0..line.len() / 2)
            .map(|i| u8::from_str_radix(&line[i * 2..i * 2 + 2], 16).unwrap())
            .collect();
        match std::str::from_utf8(&bytes) {
            Ok(_) => writeln!(out, "-1\t0").unwrap(),
            Err(error) => {
                let length = error.error_len().map_or(0, |n| n as i64);
                writeln!(out, "{}\t{}", error.valid_up_to(), length).unwrap();
            }
        }
    }
}
