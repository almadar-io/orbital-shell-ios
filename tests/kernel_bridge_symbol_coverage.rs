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
