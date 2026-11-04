#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check exact scalar/width at arbitrary offsets using Python's incremental codec."""
import codecs
import random
import subprocess
import sys
from pathlib import Path
if not __debug__:
    raise SystemExit("Do not run with -O: assertions are required")
rng = random.Random(20261105)
queries = []
def add(data, offsets):
    for at in offsets:
        queries.append((data, at))
for a in range(256):
    add(bytes([a]), (-1, 0, 1, 2))
    for b in range(256):
        add(bytes([a, b]), (0, 1))
for _ in range(5000):
    data = rng.randbytes(rng.randrange(1, 33))
    add(data, range(-1, len(data) + 2))
# Exact decoding is checked independently rather than relying on aggregate sums.
for scalar in range(0, 0x110000, 17):
    if 0xD800 <= scalar <= 0xDFFF:
        continue
    data = chr(scalar).encode()
    add(b"\xff" + data + b"\x80", range(len(data) + 2))
for data in (b"", b"ASCII", "é世😀".encode(), b"\xffvalid", b"\xf4\x90\x80\x80x"):
    add(data, (-2**63, -1, 0, len(data), len(data) + 1, 2**63 - 1))
factory = codecs.getincrementaldecoder("utf-8")
expected = []
for data, at in queries:
    result = (-1, 0)
    if 0 <= at < len(data):
        decoder = factory(errors="strict")
        for size in range(1, min(4, len(data) - at) + 1):
            try:
                char = decoder.decode(data[at + size - 1:at + size])
            except UnicodeDecodeError:
                break
            if char:
                result = (ord(char), size)
                break
    expected.append(result)
payload = "".join(f"D\t{at}\t{data.hex()}\n" for data, at in queries)
run = subprocess.run([str(Path(sys.argv[1]).resolve())], input=payload,
                     text=True, capture_output=True, check=False, timeout=120)
if run.returncode:
    sys.stderr.write(run.stderr[:4096])
    run.check_returncode()
lines = run.stdout.splitlines()
assert len(lines) == len(queries), (len(lines), len(queries))
for index, (line, want) in enumerate(zip(lines, expected)):
    got = tuple(map(int, line.split("\t")))
    assert got == want, (index, queries[index], got, want)
print(f"Python exact scalar/width oracle: {len(queries)} arbitrary-offset queries passed")
