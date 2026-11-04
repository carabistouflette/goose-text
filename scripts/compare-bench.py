#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Pair validation benchmarks in deterministic shuffled order on one CPU."""
import argparse
import hashlib
import json
import os
import platform
import random
import statistics
import subprocess
from pathlib import Path

if not __debug__:
    raise SystemExit("Do not run with -O: assertions are required")
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("baseline", type=Path)
p.add_argument("candidate", type=Path)
p.add_argument("--iterations", type=int, default=2000)
p.add_argument("--pairs", type=int, default=15)
p.add_argument("--baseline-report", type=Path)
p.add_argument("--cc", default="gcc")
p.add_argument("--output", type=Path, default=Path(".build/comparison.json"))
a = p.parse_args()
if not 1 <= a.iterations <= 10000000 or not 3 <= a.pairs <= 100:
    p.error("iterations must be 1..10000000 and pairs 3..100")
paths = {"baseline": a.baseline.resolve(), "candidate": a.candidate.resolve()}
cpu = None
if hasattr(os, "sched_getaffinity"):
    cpu = min(os.sched_getaffinity(0))
    os.sched_setaffinity(0, {cpu})
names = ["ascii", "mixed", "emoji", "ascii_spans", "invalid_early", "invalid_late"]
lengths = {}
def run(name):
    output = subprocess.check_output([str(paths[name]), str(a.iterations)], text=True, timeout=120)
    rows = [line.split("\t") for line in output.splitlines()]
    assert [r[0] for r in rows] == names + ["checksum"]
    assert int(rows[-1][1]) == a.iterations * 16391
    sample = {}
    for fixture, ns, count, size in rows[:-1]:
        assert int(count) == a.iterations and int(ns) >= 0 and int(size) > 0
        if fixture in lengths:
            assert lengths[fixture] == int(size)
        lengths[fixture] = int(size)
        sample[fixture] = int(ns)
    return sample
for name in paths:
    run(name)
rng = random.Random(20261105)
raw = []
for _ in range(a.pairs):
    order = list(paths)
    rng.shuffle(order)
    raw.append({"order": order, "ns": {name: run(name) for name in order}})
medians = {name: {fixture: statistics.median(row["ns"][name][fixture] for row in raw) / a.iterations
                  for fixture in names} for name in paths}
baseline_report = json.loads(a.baseline_report.read_text()) if a.baseline_report else None
if baseline_report:
    assert baseline_report["binary_sha256"] == hashlib.sha256(paths["baseline"].read_bytes()).hexdigest()
    assert baseline_report["compiler_revision"] == Path("GOOSE_REVISION").read_text().strip()
report = {
    "baseline_measurement": baseline_report,
    "cc_version": subprocess.check_output([a.cc, "--version"], text=True).splitlines()[0],
    "flags": "goose build -O2",
    "platform": platform.platform(), "affinity_cpu": cpu, "seed": 20261105,
    "iterations": a.iterations, "warmup_processes_per_binary": 1,
    "pairs": raw, "input_bytes": lengths, "median_ns_per_operation": medians,
    "binary_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in paths.items()},
    "candidate_source_sha256": hashlib.sha256(Path("text.goose").read_bytes()).hexdigest(),
    "compiler_revision": Path("GOOSE_REVISION").read_text().strip(),
    "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
    "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], text=True).strip()),
    "scope": "Paired warm validation timings; deterministic shuffled order; not a universal ranking. See paired run notes for baseline source and compiler metadata.",
}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(report, indent=2) + "\n")
print("Paired raw measurements: " + str(a.output))
for name in names:
    before = medians["baseline"][name]
    ratio = round(medians["candidate"][name] / before, 3) if before else "unresolved (zero baseline time)"
    print(name, "candidate/baseline ratio of medians", ratio)
