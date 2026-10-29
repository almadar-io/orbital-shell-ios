//! Gate: `OrbitalKernelBridge.swift`'s `@_silgen_name` declarations cover
//! every `orbital_kernel_*` C ABI symbol `orbital-ffi::kernel_c_api` defines
//! (read from the crate constant, never a hand-typed twin — the same shape
//! as `orbital-shell-android`'s `bridge_routes_game_canvas.rs`), and the
//! backend actually emits the file into the generated Xcode project.

use orbital_core_base::generate::Backend;
use orbital_core_base::ir::OirModule;
use orbital_shell_ios::IosBackend;

const KERNEL_BRIDGE_SWIFT: &str = include_str!("../renderers/swiftui/renderers/bridge/OrbitalKernelBridge.swift");

#[test]
fn kernel_bridge_declares_every_c_abi_symbol() {
    for symbol in orbital_ffi::kernel_c_api::KERNEL_C_SYMBOLS {
        let needle = format!("@_silgen_name(\"{symbol}\")");
        assert!(
            KERNEL_BRIDGE_SWIFT.contains(&needle),
            "OrbitalKernelBridge.swift missing `{needle}`"
        );
    }
}

#[test]
fn backend_emits_kernel_bridge_file() {
    let backend = IosBackend::new();
    let module = OirModule::new("TestApp", "1.0.0");
    let output = backend.generate(&module);

    let paths: Vec<&str> = output.files.iter().map(|f| f.path.as_str()).collect();
    assert!(
        paths.contains(&"Views/core/bridge/OrbitalKernelBridge.swift"),
        "backend does not emit OrbitalKernelBridge.swift; got: {:?}",
        paths
    );

    let bridge = output
        .files
        .iter()
        .find(|f| f.path == "Views/core/bridge/OrbitalKernelBridge.swift")
        .unwrap();
    assert!(bridge.content.contains("orbital_kernel_init"));
    assert!(bridge.content.contains("final class OrbitalKernel"));
}

const VIEW_MODEL_SWIFT: &str = include_str!("../hosts/OrbitalViewModel.swift.tpl");

/// K5 (EXEC-DIST-7): the bridge decodes the response's `frames` delta, applies it at the version it starts from, asks
/// the kernel for `framesSince` on a gap, and nothing reads the retired response `entityByTrait`.
#[test]
fn the_bridge_applies_frame_deltas_by_version_and_reads_no_response_entity_by_trait() {
    assert!(KERNEL_BRIDGE_SWIFT.contains("let frames: KernelFrameDelta?"));
    assert!(KERNEL_BRIDGE_SWIFT.contains("orbital_kernel_frames_since"));
    assert!(KERNEL_BRIDGE_SWIFT.contains("struct KernelFrameView"));
    assert!(VIEW_MODEL_SWIFT.contains("frameView.apply(delta) == .gap"));
    assert!(VIEW_MODEL_SWIFT.contains("resyncFrames"));
    assert!(!VIEW_MODEL_SWIFT.contains("response.entityByTrait"));
    let response_struct = KERNEL_BRIDGE_SWIFT.split("struct KernelEventResponse").nth(1).unwrap().split("struct KernelTraitFrom").next().unwrap();
    assert!(!response_struct.contains("entityByTrait"), "the response keeps no entityByTrait");
}
