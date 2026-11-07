#!/bin/bash
set -euo pipefail

APP_NAME="{{APP_NAME}}"
xcodegen generate --spec project.yml
DESTINATION="generic/platform=iOS Simulator"
xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Debug \
    -destination "${DESTINATION}" CODE_SIGNING_ALLOWED=NO build

if [[ "${1:-}" == "--run" ]]; then
    : "${ORB_NATIVE_SCRIPTS:?set ORB_NATIVE_SCRIPTS to orbital-rust/scripts/native (it holds ios-device.sh)}"
    DEVICE_SCRIPT="${ORB_NATIVE_SCRIPTS}/ios-device.sh"
    BUILD_SETTINGS=$(xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Debug \
        -destination "${DESTINATION}" CODE_SIGNING_ALLOWED=NO -showBuildSettings)
    BUILT_PRODUCTS_DIR=$(echo "$BUILD_SETTINGS" | grep -m1 " BUILT_PRODUCTS_DIR " | sed 's/.*= //')
    FULL_PRODUCT_NAME=$(echo "$BUILD_SETTINGS" | grep -m1 " FULL_PRODUCT_NAME " | sed 's/.*= //')
    BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER:" project.yml | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER:[[:space:]]*//')
    "$DEVICE_SCRIPT" boot
    "$DEVICE_SCRIPT" install "${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"
    "$DEVICE_SCRIPT" launch "$BUNDLE_ID" ${ORB_LAUNCH_ENV:-}
    "$DEVICE_SCRIPT" settle
    "$DEVICE_SCRIPT" screenshot "${SCREENSHOT:-./orb-run.png}"
fi
