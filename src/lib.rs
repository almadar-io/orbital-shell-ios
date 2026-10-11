//! Native iOS shell for the Orbital compiler.
//!
//! Emits a SwiftUI Xcode project from an `OirModule`.

mod backend;
mod pack;
mod shell;
pub mod shell_program;

pub use backend::{classify_oir_type, ios_snapshot_excluded, IosBackend, IOS_SNAPSHOT_EXCLUDED};
pub use pack::{require_renderer_pack, RENDERER_INTERFACE};
pub use shell::IosShell;
