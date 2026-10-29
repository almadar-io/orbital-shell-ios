#!/bin/bash
set -e

APP_NAME="{{APP_CLASS_NAME}}"

if ! command -v xcodegen &> /dev/null; then
    echo "xcodegen is not installed. Install it with: brew install xcodegen"
    exit 1
fi

echo "Generating Xcode project with xcodegen..."
xcodegen generate

if ! command -v xcodebuild &> /dev/null; then
    echo "xcodebuild is not available. On macOS, install Xcode to build this project."
    exit 1
fi

: "${CARGO_BUILD_DIR:?set CARGO_BUILD_DIR to the Cargo target dir holding aarch64-apple-ios-sim/release/liborbital_ffi.a (e.g. make ios-lib in orbital-rust, then export CARGO_BUILD_DIR=<orbital-rust>/target)}"

DESTINATION="generic/platform=iOS Simulator"

# Identity provider for native sign-in (Info.plist keys OrbitalFirebaseApiKey / OrbitalFirebaseProjectId /
# OrbitalAuthEmulatorHost). Blank leaves sign-in unconfigured.
AUTH_SETTINGS=(
    "ORBITAL_FIREBASE_API_KEY=${ORBITAL_FIREBASE_API_KEY:-}"
    "ORBITAL_FIREBASE_PROJECT_ID=${ORBITAL_FIREBASE_PROJECT_ID:-}"
    "ORBITAL_AUTH_EMULATOR_HOST=${ORBITAL_AUTH_EMULATOR_HOST:-}"
)

# Device lifecycle (boot/install/launch/screenshot) lives in orbital-rust's
# scripts/native, next to the Cargo target dir CARGO_BUILD_DIR points at.
DEVICE_SCRIPT="${ORB_NATIVE_SCRIPTS:-${CARGO_BUILD_DIR}/../scripts/native}/ios-device.sh"
SIM_DEVICE="$("$DEVICE_SCRIPT" device)"
export ORB_SIM_DEVICE="$SIM_DEVICE"

echo "Building for iOS Simulator..."
xcodebuild -scheme "${APP_NAME}" -destination "${DESTINATION}" CARGO_BUILD_DIR="${CARGO_BUILD_DIR}" "${AUTH_SETTINGS[@]}" build

if [[ "$1" == "--test" ]]; then
    # Program C wave C4 render gate (docs/Almadar_Compiler_Gaps.md §157):
    # runs the {{APP_CLASS_NAME}}Tests target (PatternSnapshotTests, generated
    # by IosBackend) on a real booted simulator — `xcodebuild test` refuses a
    # `generic/platform=` destination, unlike the plain `build` above.
    "$DEVICE_SCRIPT" require
    echo "Running XCTest suite on \"$SIM_DEVICE\"..."
    xcodebuild test -scheme "${APP_NAME}" -destination "platform=iOS Simulator,name=${SIM_DEVICE}" \
        CARGO_BUILD_DIR="${CARGO_BUILD_DIR}" "${AUTH_SETTINGS[@]}"
    exit $?
fi

if [[ "$1" == "--run" ]]; then
    # Read declared build settings rather than guessing the .app path.
    BUILD_SETTINGS=$(xcodebuild -scheme "${APP_NAME}" -destination "${DESTINATION}" CARGO_BUILD_DIR="${CARGO_BUILD_DIR}" "${AUTH_SETTINGS[@]}" -showBuildSettings)
    BUILT_PRODUCTS_DIR=$(echo "$BUILD_SETTINGS" | grep -m1 " BUILT_PRODUCTS_DIR " | sed 's/.*= //')
    FULL_PRODUCT_NAME=$(echo "$BUILD_SETTINGS" | grep -m1 " FULL_PRODUCT_NAME " | sed 's/.*= //')
    APP_PATH="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"

    # Bundle id is substituted into project.yml at compile time.
    BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER:" project.yml | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER:[[:space:]]*//')

    "$DEVICE_SCRIPT" boot
    "$DEVICE_SCRIPT" install "$APP_PATH"
    # ORB_LAUNCH_ENV: space-separated KEY=VALUE pairs for the app's launch environment.
    APP_PID=$("$DEVICE_SCRIPT" launch "$BUNDLE_ID" ${ORB_LAUNCH_ENV:-})
    "$DEVICE_SCRIPT" settle

    SCREENSHOT="${SCREENSHOT:-./orb-run.png}"
    "$DEVICE_SCRIPT" screenshot "$SCREENSHOT"
    echo "App pid: $APP_PID"

    echo "App: $APP_PATH"
    echo "Screenshot: $SCREENSHOT"
fi
