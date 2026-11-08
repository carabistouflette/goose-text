#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare validate_utf8_detailed with Python's strict codec and, when present,
with Rust's std::str::Utf8Error::error_len.

The Goose adapter prints "offset<TAB>length" per input. Python's
UnicodeDecodeError gives start/end/reason; Rust's error_len() gives the same
length for every non-truncated error and None for truncation, which this library
reports as 0. Both oracles are independent of the Goose implementation.
"""
import argparse
import random
import subprocess
import sys
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("adapter", type=Path)
p.add_argument("--rust", type=Path, default=None, help="Rust oracle binary")
p.add_argument("--cases", type=int, default=20000)
p.add_argument("--seed", type=int, default=20261108)
a = p.parse_args()

# Deterministic corpus: every single byte, every two-byte pair around the
# interesting leads, then random bytes biased towards UTF-8 syntax.
corpus = [b""]
corpus += [bytes([b]) for b in range(256)]
leads = [0x00, 0x41, 0x7F, 0x80, 0xBF, 0xC0, 0xC1, 0xC2, 0xDF, 0xE0, 0xE1,
         0xEC, 0xED, 0xEE, 0xEF, 0xF0, 0xF1, 0xF3, 0xF4, 0xF5, 0xFF]
tails = [0x00, 0x28, 0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xBF, 0xC0, 0xFF]
for lead in leads:
    for tail in tails:
        corpus.append(bytes([lead, tail]))
        for third in (0x28, 0x80, 0xBF):
            corpus.append(bytes([lead, tail, third]))
            for fourth in (0x28, 0x80, 0xBF):
                corpus.append(bytes([lead, tail, third, fourth]))
# Valid prefixes of every length 0..24 followed by each malformed class.
malformed = [b"\x80", b"\xc0\x80", b"\xc2", b"\xc2x", b"\xe0\x9f\xbf",
             b"\xed\xa0\x80", b"\xe2\x82", b"\xe2\x28\xa1", b"\xe2\x82\x28",
             b"\xf0\x8f\xbf\xbf", b"\xf4\x90\x80\x80", b"\xf5\x80\x80\x80",
             b"\xf0\x9f\x98", b"\xf0\x9f\x98\x28"]
for size in range(25):
    for tail in malformed:
        corpus.append(b"a" * size + tail)
rng = random.Random(a.seed)
for _ in range(a.cases):
    size = rng.randrange(0, 12)
    corpus.append(bytes(rng.choice(leads + tails + list(range(0x80, 0x100)))
                        for _ in range(size)))

def python_expect(data):
    try:
        data.decode("utf-8")
        return (-1, 0)
    except UnicodeDecodeError as e:
        if e.reason == "unexpected end of data":
            return (e.start, 0)
        return (e.start, e.end - e.start)

def rust_expect(data):
    out = subprocess.run([str(a.rust)], input=data.hex() + "\n", text=True,
                         capture_output=True, check=True).stdout.split()
    return (int(out[0]), int(out[1]))

payload = "".join("E\t" + data.hex() + "\n" for data in corpus)
run = subprocess.run([str(a.adapter)], input=payload, text=True,
                     capture_output=True, timeout=600)
if run.returncode:
    sys.exit("adapter failed: " + run.stdout + run.stderr)
rows = [line.split("\t") for line in run.stdout.splitlines()]
if len(rows) != len(corpus):
    sys.exit(f"adapter returned {len(rows)} rows for {len(corpus)} inputs")

rust_rows = None
if a.rust:
    rust_payload = "".join(data.hex() + "\n" for data in corpus)
    rust_run = subprocess.run([str(a.rust)], input=rust_payload, text=True,
                              capture_output=True, timeout=600, check=True)
    rust_rows = [line.split("\t") for line in rust_run.stdout.splitlines()]
    if len(rust_rows) != len(corpus):
        sys.exit(f"rust oracle returned {len(rust_rows)} rows")

failures = 0
for index, data in enumerate(corpus):
    got = (int(rows[index][0]), int(rows[index][1]))
    want = python_expect(data)
    if got != want:
        failures += 1
        print(f"python mismatch {data.hex()}: got {got} want {want}")
    if rust_rows is not None:
        rust_want = (int(rust_rows[index][0]), int(rust_rows[index][1]))
        if got != rust_want:
            failures += 1
            print(f"rust mismatch {data.hex()}: got {got} want {rust_want}")
    if failures > 20:
        sys.exit("too many mismatches")

if failures:
    sys.exit(f"{failures} diagnostic mismatches")

oracles = "Python strict codec" + (" and Rust std" if rust_rows else "")
print(f"Structured diagnostic matches {oracles} on {len(corpus)} inputs")
