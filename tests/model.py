#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Strict Python codec oracle: acceptance, sequence offsets and scalar values."""
import random
import subprocess
import sys
from pathlib import Path

if not __debug__:
    raise SystemExit("Do not run with -O: assertions are required")
rng = random.Random(20261104)
cases = [b""] + [bytes([a]) for a in range(256)]
cases.extend(bytes([a, b]) for a in range(256) for b in range(256))
for _ in range(10000):
    cases.append(rng.randbytes(rng.randrange(3, 65)))
    scalars = [rng.randrange(0x110000) for _ in range(rng.randrange(1, 40))]
    cases.append("".join(chr(c) for c in scalars if not 0xD800 <= c <= 0xDFFF).encode())
for lead in (0xC2, 0xDF, 0xE0, 0xED, 0xEF, 0xF0, 0xF4):
    for second in range(256):
        for tail in (b"", b"\x80", b"\xbf", b"\x80\x80", b"\xbf\xbf"):
            cases.append(bytes([lead, second]) + tail)
for length in range(33):
    for suffix in (b"\x80", b"\xc2", b"\xe0\xa0", b"\xf4\x90\x80\x80", b"\xf4\x8f\xbf\xbf"):
        cases.append(b"x" * length + suffix + b"a" * length)
# A whole-scalar-space independent model, plus long ASCII and mixed spans.
cases.extend(["".join(chr(c) for c in range(0x110000) if not 0xD800 <= c <= 0xDFFF).encode(),
              b"a" * 1048576, (b"abcdefgh" * 64 + "é".encode()) * 2048,
              b"a" * 1048576 + b"\xf0\x90\x80"])
expected = []
for data in cases:
    try:
        decoded = data.decode("utf-8", errors="strict")
        error = -1
    except UnicodeDecodeError as exc:
        error = exc.start
        decoded = data[:error].decode("utf-8", errors="strict")
    expected.append((error, len(decoded), sum(map(ord, decoded))))
binary = str(Path(sys.argv[1]).resolve())
result = subprocess.run([binary], input="".join(data.hex() + "\n" for data in cases),
                        text=True, capture_output=True, check=True, timeout=120)
lines = result.stdout.splitlines()
assert len(lines) == len(cases), (len(lines), len(cases), result.stderr[:1000])
for index, (line, want) in enumerate(zip(lines, expected)):
    got = tuple(map(int, line.split("\t")))
    assert got == want, (index, cases[index][:80].hex(), got, want)
print(f"Python strict UTF-8 oracle: {len(cases)} cases passed")
