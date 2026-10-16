//! The ios renderer pack — generated renderer sources + pattern fixtures, read from
//! the shipped `almadar-renderers-ios` beside the shell template, else this crate's
//! `renderers/swiftui/` (`orbital_core::renderer_packs`).

use orbital_core_base::renderer_packs::{installed, RendererPack, RendererPackError};

/// The renderer interface this shell emits against; a pack generated for another
/// is refused. Bumped with pattern-sync's `RENDERER_INTERFACE`.
pub const RENDERER_INTERFACE: u64 = 2;

/// The pack, or the structured error an entry point surfaces before generating.
pub fn require_renderer_pack() -> Result<&'static RendererPack, RendererPackError> {
    installed(
        "ios",
        RENDERER_INTERFACE,
        &std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("renderers/swiftui"),
    )
}

pub(crate) fn pack() -> &'static RendererPack {
    require_renderer_pack().unwrap_or_else(|e| {
        panic!(
            "{}: {e} (the entry point must call require_renderer_pack() first)",
            e.code()
        )
    })
}
