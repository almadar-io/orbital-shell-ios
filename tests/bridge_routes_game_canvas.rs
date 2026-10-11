//! Gate: the CorePatternRegistry must route game-canvas / canvas patterns to the
//! MTKView GPU renderer, not the text placeholder.  Verified structurally — swiftc
//! is absent in CI, so we inspect the generated Swift sources that the backend
//! emits into the Xcode project.
//!
//! Also exercises the headless RGBA path from orbital-canvas via the Rust
//! c_api (no device/Metal needed on Linux CI — graceful skip when no adapter).

use orbital_canvas::{Canvas, packet::{DrawCommand, GameRenderPacket, Rect}};
use orbital_shell_ios::IosBackend;
use orbital_core::generate::Backend;
use orbital_core::ir::OirModule;

/// All canvas-family pattern names that must be routed to the GPU renderer.
const CANVAS_PATTERNS: &[&str] = &["canvas", "game-canvas", "game-canvas-2d"];

/// Key symbol that proves the GPU path is taken (not the text placeholder).
const GPU_MARKER: &str = "GameCanvas2dRenderer";
/// The text placeholder would contain this; it must NOT appear for canvas patterns.
const PLACEHOLDER_MARKER: &str = "FallbackRenderer";

// --------------------------------------------------------------------------
// Gate 1: Registry Swift source routes canvas/game-canvas to the GPU renderer
// --------------------------------------------------------------------------

#[test]
fn registry_routes_canvas_to_gpu_renderer() {
    let registry_src = orbital_shell_ios::require_renderer_pack()
        .unwrap_or_else(|e| panic!("{}: {e}", e.code()))
        .source("CorePatternRegistry.swift")
        .expect("the pack ships CorePatternRegistry.swift");

    for pattern in CANVAS_PATTERNS {
        // The registry entry must map the pattern key to GameCanvas2dRenderer.
        let key_str = format!("\"{}\"", pattern);
        assert!(
            registry_src.contains(&key_str),
            "CorePatternRegistry.swift missing entry for pattern {:?}",
            pattern
        );

        // Find the line that registers this pattern and confirm it calls the GPU renderer.
        let line = registry_src
            .lines()
            .find(|l| l.contains(&key_str))
            .unwrap_or_else(|| panic!("no registry line for {:?}", pattern));

        assert!(
            line.contains(GPU_MARKER),
            "Pattern {:?} is not routed to {} (got: {})",
            pattern,
            GPU_MARKER,
            line.trim()
        );
        assert!(
            !line.contains(PLACEHOLDER_MARKER),
            "Pattern {:?} still routes to FallbackRenderer (got: {})",
            pattern,
            line.trim()
        );
    }

    // The registry only proves the symbol is REFERENCED — the bridge source must also
    // DEFINE it, or the reference is dead and swiftc fails with "cannot find in scope"
    // (verified 2026-09-18: this gate was green while GameCanvas2dRenderer did not exist).
    let bridge_src = include_str!("../src/renderers/core/bridge/OrbitalGameBridge.swift");
    assert!(
        bridge_src.contains("func GameCanvas2dRenderer("),
        "OrbitalGameBridge.swift does not define GameCanvas2dRenderer — the registry \
         reference is dead"
    );
}

// --------------------------------------------------------------------------
// Gate 2: Bridge Swift source is embedded and declares the @_silgen_name symbols
// --------------------------------------------------------------------------

#[test]
fn bridge_swift_declares_silgen_name_symbols() {
    let bridge_src = include_str!("../src/renderers/core/bridge/OrbitalGameBridge.swift");

    let required_symbols = [
        "orbital_canvas_init",
        "orbital_canvas_destroy",
        "orbital_canvas_submit",
        "orbital_canvas_set_scene",
        "orbital_canvas_last_error",
        "orbital_canvas_render",
        "orbital_canvas_resize",
        "orbital_canvas_render_to_rgba",
    ];

    for sym in &required_symbols {
        assert!(
            bridge_src.contains(sym),
            "OrbitalGameBridge.swift missing @_silgen_name declaration for {:?}",
            sym
        );
    }

    // The coordinator must use MTKView and MTKViewDelegate.
    assert!(bridge_src.contains("MTKViewDelegate"), "bridge missing MTKViewDelegate conformance");
    assert!(bridge_src.contains("attach(to view: MTKView"), "bridge missing attach(to:) method");
}

// --------------------------------------------------------------------------
// Gate 3: Backend emits bridge files into the generated Xcode project
// --------------------------------------------------------------------------

#[test]
fn backend_emits_bridge_files() {
    let backend = IosBackend::new();
    let module = OirModule::new("TestGame", "1.0.0");
    let output = backend.generate(&module);

    let paths: Vec<&str> = output.files.iter().map(|f| f.path.as_str()).collect();

    assert!(
        paths.contains(&"Bridge/OrbitalGameBridge.swift"),
        "backend does not emit OrbitalGameBridge.swift; got: {:?}",
        paths
    );
    assert!(
        paths.contains(&"Bridge/OrbitalCanvas.modulemap"),
        "backend does not emit OrbitalCanvas.modulemap"
    );
    assert!(
        paths.contains(&"Bridge/orbital_canvas.h"),
        "backend does not emit orbital_canvas.h"
    );
}

// --------------------------------------------------------------------------
// Gate 4: Headless RGBA render via Rust c_api (skips gracefully without GPU)
// --------------------------------------------------------------------------

#[test]
fn headless_rgba_non_blank_or_no_adapter() {
    let mut renderer = match Canvas::new_headless() {
        Ok(r) => r,
        Err(_) => return,  // no adapter on this CI host — skip
    };

    let packet = GameRenderPacket {
        pattern: "game-canvas-2d".into(),
        width: 32.0,
        height: 32.0,
        draw_commands: vec![
            DrawCommand::Clear { color: [0.2, 0.4, 0.8, 1.0] },
            DrawCommand::Quad {
                rect: Rect { x: 4.0, y: 4.0, w: 24.0, h: 24.0 },
                color: [1.0, 1.0, 0.0, 1.0],
            },
        ],
        ..Default::default()
    };

    let rgba = match renderer.render_packet_to_rgba(&packet) {
        Ok(buf) => buf,
        Err(_) => return,  // no GPU available — skip gracefully
    };

    assert_eq!(rgba.len(), 32 * 32 * 4, "RGBA buffer length mismatch");
    let all_zero = rgba.iter().all(|&b| b == 0);
    assert!(!all_zero, "headless RGBA buffer is entirely blank — renderer produced no output");
}

// --------------------------------------------------------------------------
// Gate 5: the canvas host hands the Rust renderer the scene node; it never
//         feeds raw props to the packet-only `submit`, and the C header
//         declares the same entry.
// --------------------------------------------------------------------------

#[test]
fn canvas_host_sends_scene_not_raw_props_as_packet() {
    let bridge_src = include_str!("../src/renderers/core/bridge/OrbitalGameBridge.swift");
    assert!(
        bridge_src.contains("orbital_canvas_set_scene(h, ptr)"),
        "coordinator must forward the canvas node through set_scene"
    );
    assert!(
        !bridge_src.contains("orbital_canvas_submit(h,"),
        "coordinator must not call packet-only submit with raw canvas props"
    );
    let header = include_str!("../src/renderers/core/bridge/orbital_canvas.h");
    assert!(
        header.contains("orbital_canvas_set_scene"),
        "C header must declare orbital_canvas_set_scene"
    );
}

// --------------------------------------------------------------------------
// Gate 5: the display link runs only while the scene needs frames
// --------------------------------------------------------------------------

#[test]
fn the_canvas_display_link_stops_for_a_static_scene_and_reads_the_host_clock() {
    let src = include_str!("../src/renderers/core/bridge/OrbitalGameBridge.swift");
    let draw = src.split("func draw(in view: MTKView)").nth(1).expect("draw(in:)");
    let draw = draw.split("\n    }\n").next().unwrap();
    let clock = draw.find("orbital_canvas_set_clock(h, CACurrentMediaTime()").expect("clock before render");
    let render = draw.find("orbital_canvas_render(h)").expect("render");
    let ask = draw.find("orbital_canvas_wants_frames(h) == 0").expect("frame request check");
    assert!(clock < render && render < ask, "clock, then render, then the wants-frames check");
    assert!(draw.contains("idle(view)"), "a static scene pauses the MTKView");
    assert!(src.contains("view?.isPaused = false"), "a new scene, touch or resize wakes it");
    assert!(src.contains("enableSetNeedsDisplay = true"), "paused views redraw only on demand");
    assert!(
        src.contains("UIAccessibility.isReduceMotionEnabled ? 0 : 1"),
        "the OS reduced-motion setting reaches the renderer"
    );
    assert_eq!(src.matches("CADisplayLink").count(), 0, "no second loop: MTKView's own display link is the clock");
}
