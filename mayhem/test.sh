#!/usr/bin/env bash
#
# mayhem/test.sh — RUN libvirt's own compiled unit tests plus virsh known-answer checks against the
# built-in `test:///default` driver. Everything is pre-built by mayhem/build.sh (normal flags).
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
export MAYHEM_JOBS
cd "$SRC"

REPORT="${CTRF_REPORT:-$SRC/ctrf-report.json}"
rm -f "$REPORT"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "$REPORT" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

T="$SRC/build/oracle"
if [ ! -f "$T/mayhem-tests.json" ] || [ ! -x "$T/tools/virsh" ]; then
  echo "test.sh: $T is not built — mayhem/build.sh should have produced it" >&2
  emit_ctrf "libvirt" 0 1 0
  exit 1
fi

# 1) libvirt's compiled unit tests (XML/JSON/storage/qemu/... parsers with golden files).
read -r P F < <(python3 "$SRC/mayhem/run_tests.py" "$T/mayhem-tests.json")
P=${P:-0}; F=${F:-1}

# 2) virsh against the in-process test driver: each assertion compares a known answer.
export LD_LIBRARY_PATH="$T/src"
VIRSH=("$T/tools/virsh" -c test:///default)
check() { # <description> <expected substring> <command...>
  local desc="$1" want="$2"; shift 2
  local got; got=$("${VIRSH[@]}" "$@" 2>&1)
  if [[ "$got" == *"$want"* ]]; then P=$((P+1)); else F=$((F+1)); echo "FAIL virsh $desc: wanted '$want' in: $got" >&2; fi
}
check "domuuid"       "6695eb01-f6a4-8304-79aa-97f2502e193f" domuuid test
check "dominfo vcpus" "CPU(s):         2"                     dominfo test
check "domblklist"    "/guest/diskimage1"                     domblklist test
check "net-dumpxml"   "<range start='192.168.122.2' end='192.168.122.254'/>" net-dumpxml default
check "pool-list"     "default-pool   active"                 pool-list
check "version"       "Using API: TEST 12.10.0"               version

# define a guest from XML and read the formatted result back (parse -> format round trip)
cat > "$SRC/build/oracle/mayhem-guest.xml" <<'XML'
<domain type='test'><name>oracle-guest</name><uuid>c7a5fdbd-edaf-9455-926a-d65c16db1809</uuid>
<memory unit='KiB'>131072</memory><vcpu>3</vcpu><os><type>hvm</type></os></domain>
XML
got=$(printf 'define %s\ndominfo oracle-guest\ndumpxml oracle-guest\n' "$SRC/build/oracle/mayhem-guest.xml" | "${VIRSH[@]}" 2>&1)
for want in "UUID:           c7a5fdbd-edaf-9455-926a-d65c16db1809" "CPU(s):         3" "Max memory:     131072 KiB" "<vcpu placement='static'>3</vcpu>"; do
  if [[ "$got" == *"$want"* ]]; then P=$((P+1)); else F=$((F+1)); echo "FAIL virsh define round trip: wanted '$want'" >&2; fi
done

emit_ctrf "libvirt" "$P" "$F" 0
