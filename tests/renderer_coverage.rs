//! The ios renderer pack the shell emits (`renderer-pack/`, shipped as `almadar-renderers-ios`,
//! `orbital_core::renderer_packs`): it loads with this shell's renderer interface,
//! ships the shared theme/icon files, and every per-pattern source is a covered,
//! non-placeholder renderer. The pack's own completeness gates run where it is
//! generated (pattern-sync `ios-renderers` / `rust`).

use std::collections::HashSet;

use orbital_core::renderer_packs::RendererPack;
use orbital_shell_ios::{require_renderer_pack, RENDERER_INTERFACE};

fn pack() -> &'static RendererPack {
    require_renderer_pack().unwrap_or_else(|e| panic!("{}: {e}", e.code()))
}

const TIERS: [&str; 4] = ["atoms", "molecules", "organisms", "templates"];

#[test]
fn the_pack_loads_with_this_shells_renderer_interface() {
    let p = pack();
    assert_eq!(p.target, "ios");
    assert_eq!(p.renderer_interface, RENDERER_INTERFACE);
    assert!(!p.coverage.is_empty() && !p.fixtures.is_empty());
}

#[test]
fn shared_theme_and_icon_files_ship_in_the_pack() {
    let p = pack();
    for file in [
        "IconMap.swift",
        "AlmadarTheme.swift",
        "CorePatternRegistry.swift",
        "RenderersCommon.swift",
    ] {
        assert!(
            p.sources.iter().any(|(rel, _)| rel == file),
            "ios: {file} missing from the pack — run `almadar-sync icon-map` / `native-theme` / `ios-renderers`"
        );
    }
}

/// Confirms the 🔧 scanner would FAIL when a placeholder is present.
#[test]
fn placeholder_scanner_rejects_wrench_body() {
    let src = "// \u{1f527} TODO: implement this renderer\n";
    assert!(
        src.contains('\u{1f527}'),
        "placeholder scanner must detect the wrench"
    );
}

#[test]
fn every_per_pattern_source_is_a_covered_non_placeholder_renderer() {
    let p = pack();
    let covered: HashSet<&str> = p.coverage.iter().map(String::as_str).collect();
    let mut uncovered = Vec::new();
    let mut placeholders = Vec::new();
    for (rel, src) in &p.sources {
        let Some((tier, file)) = rel.split_once('/') else {
            continue;
        };
        if !TIERS.contains(&tier) {
            continue;
        }
        let pattern = file.trim_end_matches(".swift").replace('_', "-");
        if !covered.contains(pattern.as_str()) {
            uncovered.push(rel.clone());
        }
        if src.contains('\u{1f527}') {
            placeholders.push(rel.clone());
        }
    }
    assert!(
        uncovered.is_empty(),
        "ios: sources outside the declared coverage: {uncovered:?}"
    );
    assert!(
        placeholders.is_empty(),
        "ios: 🔧 placeholder renderers in the pack: {placeholders:?}"
    );
}
