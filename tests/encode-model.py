#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare all scalar encodings directly with Python, without library decoding."""
import subprocess
import sys
if not __debug__:
    raise SystemExit("Do not run with -O: assertions are required")
if len(sys.argv) < 2:
    raise SystemExit("usage: encode-model.py ENCODER_COMMAND [ARG ...]")
expected = b"prefix" + "".join(chr(cp) for cp in range(0x110000)
                             if not 0xD800 <= cp <= 0xDFFF).encode("utf-8", errors="strict")
run = subprocess.run(sys.argv[1:], capture_output=True, check=False, timeout=120)
if run.returncode:
    sys.stderr.buffer.write(run.stderr[:4096])
    run.check_returncode()
assert run.stdout == expected, (len(run.stdout), len(expected), "encoder bytes differ")
print("Python exact encoder oracle: all 1,112,064 Unicode scalars passed")
