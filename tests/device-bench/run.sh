#!/bin/bash
# R1-device-ios: build the bench host against the simulator staticlib and run it inside the booted simulator.
#   run.sh <workload-dir> [--sustained]
# Needs `make ios-lib` (orbital-rust/target/aarch64-apple-ios-sim/release/liborbital_ffi.a) and a booted simulator.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_ROOT="$(cd "$HERE/../../../.." && pwd)"
LIB="${ORBITAL_FFI_LIB:-$RUST_ROOT/target/aarch64-apple-ios-sim/release/liborbital_ffi.a}"
OUT="${ORB_BENCH_OUT:-$RUST_ROOT/target/device-bench/ios}"
[ -f "$LIB" ] || { echo "missing $LIB: run 'make ios-lib' in orbital-rust" >&2; exit 1; }
[ -d "${1:?usage: run.sh <workload-dir> [--sustained]}" ] || { echo "no workload dir $1" >&2; exit 1; }
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
mkdir -p "$OUT"
xcrun swiftc -O -target arm64-apple-ios17.0-simulator -sdk "$SDK" \
  -import-objc-header "$HERE/orbital_kernel.h" "$HERE/main.swift" "$LIB" \
  -Xlinker -framework -Xlinker Metal -Xlinker -framework -Xlinker QuartzCore -Xlinker -framework -Xlinker Foundation \
  -Xlinker -framework -Xlinker CoreGraphics -Xlinker -framework -Xlinker Security -Xlinker -framework -Xlinker SystemConfiguration \
  -Xlinker -liconv -Xlinker -lresolv -Xlinker -lc++ -Xlinker -w -o "$OUT/bench"
DEVICE="${ORB_SIM_DEVICE:-booted}"
xcrun simctl spawn "$DEVICE" "$OUT/bench" "$@"
