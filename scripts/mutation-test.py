#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check that representative codec mistakes are rejected by executable tests."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--goose", type=Path, required=True)
p.add_argument("--cc", default="gcc")
a = p.parse_args()
goose = str(a.goose.resolve())
original = (ROOT / "text.goose").read_text()
# Each detector is selected explicitly: a different failing suite is not counted.
mutants = [
    ("ascii_eighth_byte", "api", [("chunk[6] | chunk[7]", "chunk[6] | 0")]),
    ("overlong_lead", "api", [("lead >= 0xc2", "lead >= 0xc0")]),
    ("surrogate_decode", "api", [("        if lead == 0xed { hi = 0x9f; }", "")]),
    ("above_unicode_max", "api", [("        if lead == 0xf4 { hi = 0x8f; }", "        if lead == 0xf4 { hi = 0x90; }")]),
    ("later_continuation", "model", [("if byte < 0x80 || byte > 0xbf { return -1, 0; }", "")]),
    ("wrong_error_offset", "api", [("if width == 0 { return at; }", "if width == 0 { return at + 1; }")]),
    ("invalid_prefix_blocks_suffix", "decode", [("let lead = source[offset];", "if offset > 0 && source[0] == 0xff { return -1, 0; }\n    let lead = source[offset];")]),
    ("mutate_before_reject", "api", [("{ return false; }", "{ out.clear(); return false; }")]),
    ("surrogate_encode", "api", [("(scalar >= 0xd800 && scalar <= 0xdfff)", "false")]),
    ("truncation_off_by_one", "api", [("width > source.len - offset", "width > source.len - offset + 1")]),
    # Structured diagnostics: each mutant must be caught by the api suite, which
    # pins exact (offset, length) pairs for every malformed class.
    ("detail_illegal_lead_as_truncation", "api", [(
        "if lead < 0xc2 || lead > 0xf4 { return Utf8Error { offset: at, length: 1 }; }",
        "if lead < 0xc2 || lead > 0xf4 { return Utf8Error { offset: at, length: 0 }; }")]),
    ("detail_truncation_as_replaceable", "api", [(
        "if i >= source.len - at { return Utf8Error { offset: at, length: 0 }; }",
        "if i >= source.len - at { return Utf8Error { offset: at, length: i }; }")]),
    ("detail_length_always_one", "api", [(
        "if byte < low || byte > high { return Utf8Error { offset: at, length: i }; }",
        "if byte < low || byte > high { return Utf8Error { offset: at, length: 1 }; }")]),
    ("detail_drops_surrogate_bound", "api", [(
        "    if lead == 0xe0 { lo = 0xa0; }\n    if lead == 0xed { hi = 0x9f; }",
        "    if lead == 0xe0 { lo = 0xa0; }")]),
    ("detail_drops_e0_bound", "api", [("\n    if lead == 0xe0 { lo = 0xa0; }", "")]),
    ("detail_drops_f0_bound", "api", [("\n    if lead == 0xf0 { lo = 0x90; }", "")]),
    ("detail_drops_f4_bound", "api", [("\n    if lead == 0xf4 { hi = 0x8f; }", "")]),
    ("detail_drops_first_continuation_bound", "api", [(
        "let low:  u8 = if i == 1 { lo } else { 0x80 };",
        "let low:  u8 = 0x80;")]),
    # A coupled encoder/decoder permutation can preserve all round trips.
    ("paired_ascii_permutation", "encode", [
        ("if lead < 0x80 { return lead, 1; }", "if lead < 0x80 { return lead ^ 1, 1; }"),
        ("push_utf8(out, scalar);", "push_utf8(out, if scalar < 0x80 { scalar ^ 1 } else { scalar });")]),
]
work = ROOT / ".build/mutation"
work.mkdir(parents=True, exist_ok=True)
(work / "results.json").unlink(missing_ok=True)

def exercise(name, source, detector, reject):
    directory = work / name
    (directory / "tests").mkdir(parents=True, exist_ok=True)
    (directory / "text.goose").write_text(source)
    suite = "api" if detector == "api" else "encoding" if detector == "encode" else "oracle"
    shutil.copyfile(ROOT / "tests" / (suite + ".goose"), directory / "tests" / (suite + ".goose"))
    binary = directory / suite
    command = [goose, "build", str(directory / "tests" / (suite + ".goose")),
               "--cc", a.cc, "-O2", "-o", str(binary)]
    build = subprocess.run(command, capture_output=True, timeout=120)
    (directory / (detector + "-build.log")).write_bytes(build.stdout + build.stderr)
    if build.returncode:
        raise RuntimeError(f"{name}/{detector}: compile failure is not a detected mutation")
    scripts = {"model": "model.py", "decode": "decode-model.py", "encode": "encode-model.py"}
    command = [str(binary)] if detector == "api" else ["python3", str(ROOT / "tests" / scripts[detector]), str(binary)]
    run = subprocess.run(command, capture_output=True, timeout=180)
    output = run.stdout + run.stderr
    (directory / (detector + "-run.log")).write_bytes(output)
    if not reject:
        if run.returncode:
            raise RuntimeError(f"unmodified control failed {detector}; see {directory}")
    else:
        markers = (b"assert failed", b"bounds", b"out of range") if detector == "api" else (b"AssertionError", b"assert failed", b"bounds", b"out of range")
        if run.returncode == 0 or not any(marker in output for marker in markers):
            raise RuntimeError(f"{name}: survived or unexpected failure; see {directory}")

for detector in ("api", "model", "decode", "encode"):
    exercise("control", original, detector, False)
print("Unmodified controls passed", flush=True)
results = []
for name, detector, patches in mutants:
    source = original
    for before, after in patches:
        if source.count(before) != 1:
            raise RuntimeError(f"{name}: mutation anchor must match exactly once")
        source = source.replace(before, after)
    exercise(name, source, detector, True)
    results.append({"mutation": name, "detector": detector, "detected": True})
    print(name + ": detected by " + detector, flush=True)
(work / "results.json").write_text(json.dumps({
    "source_sha256": hashlib.sha256(original.encode()).hexdigest(),
    "cc_version": subprocess.check_output([a.cc, "--version"], text=True).splitlines()[0],
    "controls": ["api", "model", "decode", "encode"],
    "mutations": results,
}, indent=2) + "\n")
print(f"Detected all {len(results)} representative mutations; production source untouched")
