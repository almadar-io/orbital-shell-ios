#!/usr/bin/env bash
set -euo pipefail

: "${CARGO_TARGET_DIR:?set the isolated Cargo target directory}"
: "${ORB_GPU_PROGRAM:?set the validated .orb program path}"
: "${ORB_GPU_LANGUAGE:?set the installed language bundle JSON path}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stage_dir="${ORB_GPU_STAGE:-$(mktemp -d "${TMPDIR:-/tmp}/orb-ios-native.XXXXXX")}"
target="${ORB_GPU_TARGET:-aarch64-apple-ios}"
features="${ORB_GPU_FEATURES-research-video}"
args=(build --manifest-path "$script_dir/../host/Cargo.toml" --target "$target")
if [[ -n "$features" ]]; then
    args+=(--features "$features")
fi
cargo "${args[@]}"

mkdir -p "$stage_dir"
cp "$script_dir/main.c" "$script_dir/OrbitalVideoOverlay.m" "$script_dir/OrbitalMotion.m" "$script_dir/project.yml" "$stage_dir/"
cp "$ORB_GPU_PROGRAM" "$stage_dir/program.orb"
cp "$ORB_GPU_LANGUAGE" "$stage_dir/language.json"
(
    cd "$stage_dir"
    xcodegen generate --spec project.yml
    xcodebuild -project OrbitalNativeGpu.xcodeproj -scheme OrbitalNativeGpu \
        -configuration Debug -destination 'generic/platform=iOS' \
        "ORB_GPU_LIB_DIR=$CARGO_TARGET_DIR/$target/debug" CODE_SIGNING_ALLOWED=NO build
)
printf 'iOS native GPU link probe: %s\n' "$stage_dir"
