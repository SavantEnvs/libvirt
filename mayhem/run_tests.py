#!/usr/bin/env python3
"""Run libvirt's own compiled unit tests directly (no meson test) and report passed/failed.

A test passes only if it exits 0 AND its output ends with the framework's final "OK" marker, so a
process that exits early without running its cases counts as a failure.
"""
import concurrent.futures as cf
import json
import os
import subprocess
import sys

tests = json.load(open(sys.argv[1]))
jobs = int(os.environ.get("MAYHEM_JOBS") or os.cpu_count() or 4)


def run(t):
    env = dict(os.environ)
    env.update(t["env"])
    try:
        p = subprocess.run(t["cmd"], env=env, cwd=t["workdir"], capture_output=True, text=True, timeout=600)
    except subprocess.TimeoutExpired:
        return t["name"], False, "timeout"
    out = (p.stdout + p.stderr).split()
    ok = p.returncode == 0 and out[-1:] == ["OK"]
    return t["name"], ok, "" if ok else "rc=%d last=%r" % (p.returncode, out[-1:])


with cf.ThreadPoolExecutor(jobs) as ex:
    results = list(ex.map(run, tests))
passed = sum(1 for _, ok, _ in results if ok)
for name, ok, why in results:
    if not ok:
        print("FAIL %s: %s" % (name, why), file=sys.stderr)
print("%d %d" % (passed, len(results) - passed))
