//! `orb-shell-ios`: the iOS shell as a program (`orbital_core::shell_protocol`).

use orbital_core_base::project::write_project;
use orbital_core_base::shell_protocol::{
    description, written_files, GenerateRequest, GenerateResponse, ShellDescription, ShellFailure, ShellProgram,
    CODE_BAD_REQUEST, CODE_GENERATE_FAILED,
};
use std::path::Path;

pub struct IosProgram;

fn resolved(request: &GenerateRequest) -> Result<orbital_core_base::schema::types::OrbitalSchema, ShellFailure> {
    request
        .resolved
        .clone()
        .ok_or_else(|| ShellFailure::new(CODE_BAD_REQUEST, "the ios shell needs the resolved program"))
}

impl ShellProgram for IosProgram {
    fn describe(&self) -> ShellDescription {
        description("ios", env!("CARGO_PKG_VERSION"), true, Vec::new())
    }

    fn generate(&self, request: &GenerateRequest, output: &Path) -> Result<GenerateResponse, ShellFailure> {
        crate::require_renderer_pack().map_err(|e| ShellFailure::new(CODE_GENERATE_FAILED, format!("{}: {e}", e.code())))?;
        let shell = crate::IosShell::new();
        let backend = crate::IosBackend::new().with_resolved_schema(resolved(request)?);
        let generated = write_project(&request.module, output, &shell, &backend, &request.write)?;
        let files = written_files(&generated);
        if request.write.copy_template {
            use orbital_core_base::shell::Shell as _;
            let failed = |e: orbital_core_base::shell::ShellError| ShellFailure::new(CODE_GENERATE_FAILED, e.to_string());
            shell.validate_structure(output).map_err(failed)?;
            shell.validate_generated_layout(output, &files).map_err(failed)?;
        }
        Ok(GenerateResponse {
            files,
            warnings: generated.warnings,
            next_steps: vec![format!("cd {}", output.display()), "./orb-build.sh".to_string()],
        })
    }
}
