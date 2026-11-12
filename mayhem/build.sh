#!/usr/bin/env bash
#
# mayhem/build.sh — build libvirt's fuzz harnesses (sanitized) and the project's test suite (normal flags).
# Runs inside the commit image as `mayhem` in /mayhem; re-runnable and offline (SPEC §6.5).
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# libvirt's UBSan -fsanitize=function hits its pervasive (GDestroyNotify)virFoo callback casts on the first
# allocation; relax only that check. The sanitizer runtimes also make meson's has_function probes succeed
# spuriously for symbols that do not exist on Linux, so no sanitizer flag may reach `meson setup` itself:
# they go in via the compile commands through CFLAGS only after a plain configure (see FUZZ_CFLAGS below).
FUZZ_CFLAGS="$SANITIZER_FLAGS -fno-sanitize=function $DEBUG_FLAGS -fsanitize=fuzzer-no-link"

MESON_OPTS=(
  -Dtests=disabled -Ddocs=disabled -Dnls=disabled -Dwerror=false -Dwarning_level=0
  -Ddriver_esx=disabled -Ddriver_vbox=disabled -Ddriver_libxl=disabled -Ddriver_ch=disabled
  -Ddriver_bhyve=disabled -Ddriver_vmware=disabled -Ddriver_hyperv=disabled -Ddriver_openvz=disabled
  -Ddriver_vz=disabled -Ddriver_lxc=disabled -Ddriver_interface=disabled
  -Dstorage_rbd=disabled -Dstorage_gluster=disabled -Dstorage_iscsi=disabled
  -Dstorage_iscsi_direct=disabled -Dstorage_zfs=disabled -Dstorage_vstorage=disabled
  -Dselinux=disabled -Dapparmor=disabled -Daudit=disabled -Dfirewalld=disabled -Dpolkit=disabled
  -Dsasl=disabled -Dlibssh=disabled -Dlibssh2=disabled -Dsanlock=disabled
)

# 1) The sanitized project: libvirt's internal static archives (the code the harnesses link).
B="$SRC/build"
if [ ! -f "$B/build.ninja" ]; then
  CFLAGS="$FUZZ_CFLAGS" meson setup "$B" "${MESON_OPTS[@]}"
fi
ARCHIVES=(
  src/util/libvirt_util.a src/conf/libvirt_conf.a src/rpc/libvirt_socket.a src/rpc/libvirt_net_rpc.a
  src/rpc/libvirt_net_rpc_client.a src/rpc/libvirt_net_rpc_server.a src/access/libvirt_access.a
  src/cpu/libvirt_cpu.a src/hypervisor/libvirt_hypervisor.a src/remote/libvirt_remote_driver.a
  src/locking/libvirt_lock_driver.a src/logging/libvirt_log_driver.a src/security/libvirt_security_manager.a
  src/storage_file/libvirt_storage_file.a src/test/libvirt_test.a src/libvirt_driver.a
)
ninja -C "$B" -j"$MAYHEM_JOBS" "${ARCHIVES[@]}"

# Flags a harness needs: include paths and the external libraries libvirt's own link line uses.
INCS=$(ninja -C "$B" -t commands src/conf/libvirt_conf.a.p/domain_conf.c.o | tail -1 | grep -oE ' -I[^ ]+' | sed "s# -I\([^/]\)# -I$B/\1#g" | tr '\n' ' ')
SO=$(ninja -C "$B" -t targets all | grep -oE '^src/libvirt\.so\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
EXTLIBS=$(ninja -C "$B" -t commands "$SO" | tail -1 | tr ' ' '\n' | grep -E '^/usr/.*\.so$|^-l' | awk '!s[$0]++' | tr '\n' ' ')
EXTLIBS="$EXTLIBS $(pkg-config --libs libtirpc gnutls)"
ARCS=$(for a in "${ARCHIVES[@]}"; do printf '%s ' "$B/$a"; done)

HARNESS_CFLAGS="$SANITIZER_FLAGS -fno-sanitize=function $DEBUG_FLAGS -fsanitize=fuzzer-no-link -D_FILE_OFFSET_BITS=64 -std=gnu99 -O1 -pthread $INCS"

$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$B/lsan_off.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$B/standalone_main.o"

TARGETS=(fuzz_domain_xml fuzz_network_xml fuzz_storagepool_xml fuzz_storagevol_xml fuzz_json fuzz_storage_header fuzz_nodedev_xml fuzz_secret_xml fuzz_nwfilter_xml)
for t in "${TARGETS[@]}"; do
  $CC $HARNESS_CFLAGS -I"$SRC/mayhem/harnesses" -c "$SRC/mayhem/harnesses/$t.c" -o "$B/$t.o"
  $CC $SANITIZER_FLAGS -fno-sanitize=function $DEBUG_FLAGS $LIB_FUZZING_ENGINE -pthread \
      "$B/$t.o" "$B/lsan_off.o" -Wl,--start-group $ARCS -Wl,--end-group $EXTLIBS -lm -ldl -o "/mayhem/$t"
  $CC $SANITIZER_FLAGS -fno-sanitize=function $DEBUG_FLAGS -pthread \
      "$B/$t.o" "$B/standalone_main.o" "$B/lsan_off.o" -Wl,--start-group $ARCS -Wl,--end-group $EXTLIBS -lm -ldl -o "/mayhem/$t-standalone"
done

# 2) The project's own test suite with NORMAL flags (clang -O0: libvirt's mock library needs either
#    -fsemantic-interposition or optimization off), in a separate tree under the gitignored /build/.
T="$SRC/build/oracle"
if [ ! -f "$T/build.ninja" ]; then
  env -u CFLAGS -u CXXFLAGS -u LDFLAGS meson setup "$T" -Doptimization=0 "${MESON_OPTS[@]}" -Dtests=enabled
fi
env -u CFLAGS -u CXXFLAGS -u LDFLAGS ninja -C "$T" -j"$MAYHEM_JOBS"
meson introspect --tests "$T" | python3 -c '
import json, sys
t = json.load(sys.stdin)
skip = {"commandtest", "vshtabletest", "test_demo"}
keep = [
    {"name": x["name"], "cmd": x["cmd"], "env": x["env"], "workdir": x["workdir"] or sys.argv[1] + "/tests"}
    for x in t
    if x["cmd"][0].startswith(sys.argv[1] + "/tests/") and x["name"] not in skip
]
json.dump(keep, open(sys.argv[1] + "/mayhem-tests.json", "w"))
print("oracle: %d unit tests" % len(keep))
' "$T"
