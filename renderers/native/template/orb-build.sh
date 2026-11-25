#!/bin/bash
set -euo pipefail

APP_NAME="{{APP_NAME}}"
mkdir -p lazy fonts
xcodegen generate --spec project.yml

if [[ "${1:-}" == "--device" ]]; then
    : "${ORB_IOS_TEAM:?set ORB_IOS_TEAM to your Apple development team id (Xcode > Settings > Accounts)}"
    DEVICE="${ORB_IOS_DEVICE:-}"
    if [[ -z "${DEVICE}" ]]; then
        DEVICES_JSON="$(mktemp)"
        xcrun devicectl list devices --json-output "${DEVICES_JSON}" >/dev/null
        DEVICE="$(plutil -extract result.devices.0.hardwareProperties.udid raw "${DEVICES_JSON}" 2>/dev/null || true)"
        rm -f "${DEVICES_JSON}"
    fi
    : "${DEVICE:?connect and trust an iPhone, or set ORB_IOS_DEVICE to its UDID}"
    xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Debug \
        -destination "platform=iOS,id=${DEVICE}" DEVELOPMENT_TEAM="${ORB_IOS_TEAM}" \
        -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
    BUILT_PRODUCTS_DIR=$(xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Debug \
        -destination "platform=iOS,id=${DEVICE}" DEVELOPMENT_TEAM="${ORB_IOS_TEAM}" -showBuildSettings \
        | grep -m1 " BUILT_PRODUCTS_DIR " | sed 's/.*= //')
    BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER:" project.yml | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER:[[:space:]]*//')
    xcrun devicectl device install app --device "${DEVICE}" "${BUILT_PRODUCTS_DIR}/${APP_NAME}.app"
    xcrun devicectl device process launch --device "${DEVICE}" --terminate-existing "${BUNDLE_ID}"
    exit 0
fi

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
