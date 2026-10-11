//! Parity gate: the emitted Swift `slotRole()` classifier must agree with
//! `orbital_core::slots::slot_role` for every canonical slot name.
//!
//! SwiftUI is not compiled in CI, so we assert structural parity by checking
//! that the emitted `SlotRole.swift` source contains the correct per-name arm
//! for each canonical slot, and that `GeneratedApp.swift` dispatches overlays via
//! `slotRole()` rather than hardcoded key lookups.

use orbital_core::generate::Backend;
use orbital_core::ir::OirModule;
use orbital_core::slots::{slot_role, SlotRole};
use orbital_shell_ios::IosBackend;

/// Canonical names from `orbital_core::slots` and their expected roles.
const CANONICAL_CASES: &[(&str, SlotRole)] = &[
    ("main", SlotRole::Main),
    ("content", SlotRole::Main),
    ("screen", SlotRole::Main),
    ("sidebar", SlotRole::Sidebar),
    ("drawer", SlotRole::Drawer),
    ("modal", SlotRole::Modal),
    ("center", SlotRole::Modal),
    ("overlay", SlotRole::Overlay),
    ("overlay.dialogue", SlotRole::Overlay),
    ("toast", SlotRole::Toast),
    ("hud", SlotRole::HudTop),
    ("hud-top", SlotRole::HudTop),
    ("hud.health", SlotRole::HudTop),
    ("hud-bottom", SlotRole::HudBottom),
    ("floating", SlotRole::Floating),
    ("system", SlotRole::System),
];

/// The Swift role identifier (without the leading dot) for each `SlotRole`.
fn swift_role_id(role: SlotRole) -> &'static str {
    match role {
        SlotRole::Main => "main",
        SlotRole::Sidebar => "sidebar",
        SlotRole::Drawer => "drawer",
        SlotRole::Modal => "modal",
        SlotRole::Overlay => "overlay",
        SlotRole::Toast => "toast",
        SlotRole::HudTop => "hudTop",
        SlotRole::HudBottom => "hudBottom",
        SlotRole::Floating => "floating",
        SlotRole::System => "system",
    }
}

/// The Rust canonical owner (`orbital_core::slots::slot_role`) classifies every
/// canonical slot name correctly.
#[test]
fn core_slot_role_parity() {
    for &(name, expected) in CANONICAL_CASES {
        let got = slot_role(name);
        assert_eq!(
            got, expected,
            "orbital_core::slots::slot_role({name:?}) = {got:?}, want {expected:?}"
        );
    }
}

/// The emitted `SlotRole.swift` source contains the correct per-name arm for
/// each canonical slot.
///
/// For each (name, expected_role) pair this asserts that the emitted source
/// contains:
///   `case "<name>":`       — the exact case arm for that slot name
///   `return .<role-id>`    — the return that arm resolves to
///
/// Prefix-matched names (e.g. `overlay.dialogue`, `hud.health`) are covered by
/// the `default:` branch; for those we assert the `hasPrefix` guard and the
/// corresponding `return .<role-id>` both appear in the emitted source.
///
/// This test is NON-VACUOUS: corrupting just one name's mapping (e.g. routing
/// "modal" to `.main` while "center" still routes to `.modal`) will fail the
/// assertion for "modal" because `case "modal":` is a distinct arm with its own
/// `return .modal`.
#[test]
fn emitted_swift_slot_role_parity() {
    let module = OirModule::new("PTest", "0.0.0");
    let output = IosBackend::new().generate(&module);

    let swift = output
        .files
        .iter()
        .find(|f| f.path == "SlotRole.swift")
        .expect("SlotRole.swift not emitted by IosBackend")
        .content
        .clone();

    for &(name, expected_role) in CANONICAL_CASES {
        let role_id = swift_role_id(expected_role);
        let return_arm = format!("return .{}", role_id);

        if name.contains('.') {
            // Prefix-dispatched names go through the `default:` branch.
            // Assert the hasPrefix guard and the return both appear.
            let prefix = name.split('.').next().unwrap();
            let has_prefix_guard = format!("hasPrefix(\"{}.\")", prefix);
            assert!(
                swift.contains(&has_prefix_guard),
                "SlotRole.swift missing hasPrefix guard for prefix {:?} (slot {:?} → {:?}): \
                 expected to find `{}` in emitted source",
                prefix,
                name,
                expected_role,
                has_prefix_guard,
            );
            assert!(
                swift.contains(&return_arm),
                "SlotRole.swift missing `{}` needed for slot {:?} → {:?}",
                return_arm,
                name,
                expected_role,
            );
        } else {
            // Exact-name cases must each have their own `case "<name>":` arm
            // immediately followed by `return .<role>`.  Asserting the two-line
            // sequential pattern makes this NON-VACUOUS: if "modal" is routed
            // to `.main` while "center" still returns `.modal`, the needle
            // `case "modal":\n        return .modal` won't be found and the test
            // fails, even though `return .modal` still appears elsewhere.
            let case_arm = format!("case \"{}\":", name);
            let two_line = format!("{}:\n        {}", case_arm.trim_end_matches(':'), return_arm);
            assert!(
                swift.contains(&two_line),
                "SlotRole.swift missing per-name arm `case \"{name}\": → {return_arm}` \
                 (needed for slot {name:?} → {expected_role:?}); \
                 expected the sequential pattern:\n  {case_arm}\n          {return_arm}"
            );
        }
    }
}

/// `GeneratedApp.swift` dispatches every overlay-family slot through `slotRole()` rather
/// than via hardcoded key lookups, mirroring Android's generic role-dispatch.
#[test]
fn app_file_calls_slot_role_for_overlay_dispatch() {
    let module = OirModule::new("PTest", "0.0.0");
    let output = IosBackend::new().generate(&module);

    let app = output
        .files
        .iter()
        .find(|f| f.path == "GeneratedApp.swift")
        .expect("GeneratedApp.swift not emitted by IosBackend")
        .content
        .clone();

    // Modal dispatch must route through slotRole() == .modal, not by name.
    assert!(
        app.contains("slotRole($0") || app.contains("slotRole($0.key)"),
        "GeneratedApp.swift must call slotRole() to dispatch slot roles"
    );
    assert!(
        app.contains("== .modal"),
        "GeneratedApp.swift must dispatch modal slots via slotRole() == .modal"
    );
    assert!(
        app.contains("== .drawer"),
        "GeneratedApp.swift must dispatch drawer slots via slotRole() == .drawer"
    );
    assert!(
        app.contains("== .overlay"),
        "GeneratedApp.swift must dispatch overlay slots via slotRole() == .overlay"
    );
    assert!(
        app.contains("== .hudTop"),
        "GeneratedApp.swift must dispatch HUD-top slots via slotRole() == .hudTop"
    );
    assert!(
        app.contains("== .hudBottom"),
        "GeneratedApp.swift must dispatch HUD-bottom slots via slotRole() == .hudBottom"
    );
    assert!(
        app.contains("== .toast"),
        "GeneratedApp.swift must dispatch toast slots via slotRole() == .toast"
    );
    assert!(
        app.contains("== .sidebar"),
        "GeneratedApp.swift must dispatch sidebar slots via slotRole() == .sidebar"
    );
    assert!(
        app.contains("== .floating"),
        "GeneratedApp.swift must dispatch floating slots via slotRole() == .floating"
    );

    // Must NOT use bare hardcoded key lookups for modal-family slots.
    assert!(
        !app.contains("uiSlots[\"modal\"]"),
        "GeneratedApp.swift must not hardcode uiSlots[\"modal\"] — use slotRole() dispatch"
    );
    assert!(
        !app.contains("uiSlots[\"center\"]"),
        "GeneratedApp.swift must not hardcode uiSlots[\"center\"] — use slotRole() dispatch"
    );
}
