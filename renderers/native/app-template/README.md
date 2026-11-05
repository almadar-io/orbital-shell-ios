# Standalone iOS native GPU probe

The iOS shell owns this app entry and link adapter. Its `renderers/native/host` static library exports `orbital_native_ios_main`, installs the bundled language data, mounts the bundled `.orb` program through the shared Dioxus renderer, and starts the native event loop. `main.c` calls that symbol before `UIApplicationMain`; the existing SwiftUI `@main` app cannot host a second application event loop. `OrbitalVideoOverlay.m` supplies the platform WebKit overlay called by the shared video renderer. The SwiftUI renderer remains available.

The research build script stages an XcodeGen project outside the source tree, builds `liborbital_shell_ios_native_host.a` for an iOS device, and links the app. It does not launch a simulator or device:

```sh
export CARGO_TARGET_DIR=/absolute/path/to/isolated-target
export ORB_GPU_PROGRAM=/absolute/path/to/validated-program.orb
export ORB_GPU_LANGUAGE=/absolute/path/to/language.json
renderers/native/app-template/orb-build.sh
```

`ORB_GPU_STAGE` chooses the staging directory; otherwise the script creates a temporary one. `ORB_GPU_TARGET` defaults to `aarch64-apple-ios`. `ORB_GPU_FEATURES` defaults to `research-video` to preserve the video probe; set it to an empty string to build only the native renderer. The parent Rust workspace must include `crates/orbital-shell-ios/renderers/native/host` as a member so its local patches resolve the shared kernel and Dioxus renderer.

The app resources `program.orb` and `language.json` are copied to the top level of the `.app`, where the Rust bootstrap reads them. A successful device-target linker check must resolve `_orbital_native_ios_main` from the platform static library. GPU pixels, touch, text input, media playback, and lifecycle on iOS remain unverified until a physical device is available.
