//! `orb-shell-ios`: the iOS shell as a program (`orbital_core::shell_protocol`).

use orbital_core_base::project::write_project;
use orbital_core_base::shell_protocol::{
    description, written_files, GenerateRequest, GenerateResponse, ShellDescription, ShellFailure, ShellOption, ShellProgram,
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
        description(
            "ios",
            env!("CARGO_PKG_VERSION"),
            true,
            vec![
                ShellOption {
                    name: "renderer".into(),
                    description: "iOS renderer pack".into(),
                    values: Some(vec!["swiftui".into(), "native-gpu".into()]),
                    default: Some("swiftui".into()),
                },
                ShellOption {
                    name: "backendUrl".into(),
                    description: "Server URL for the native GPU renderer".into(),
                    values: None,
                    default: None,
                },
            ],
        )
    }

    fn generate(&self, request: &GenerateRequest, output: &Path) -> Result<GenerateResponse, ShellFailure> {
        let renderer = match request.options.get("renderer") {
            None => "swiftui",
            Some(serde_json::Value::String(value)) if value == "swiftui" || value == "native-gpu" => value,
            _ => return Err(ShellFailure::new(CODE_BAD_REQUEST, "renderer must be swiftui or native-gpu")),
        };
        if renderer == "native-gpu" {
            return generate_native_gpu(request, output);
        }
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

fn generate_native_gpu(request: &GenerateRequest, output: &Path) -> Result<GenerateResponse, ShellFailure> {
    let schema = resolved(request)?;
    let language = orbital_core_base::language_data::language_bundle_json()
        .map_err(|e| ShellFailure::new(CODE_GENERATE_FAILED, format!("load installed language bundle: {e}")))?;
    let backend_url = match request.options.get("backendUrl") {
        None => None,
        Some(serde_json::Value::String(url)) if is_http_url(url) => Some(url.as_str()),
        _ => return Err(ShellFailure::new(CODE_BAD_REQUEST, "backendUrl must be an HTTP(S) URL")),
    };
    let backend = crate::native_gpu::NativeGpuBackend::new(&schema, language, backend_url)
        .map_err(|e| ShellFailure::new(CODE_GENERATE_FAILED, format!("serialize resolved program: {e}")))?;
    let shell = crate::native_gpu::NativeGpuShell::new().map_err(|e| ShellFailure::new(CODE_GENERATE_FAILED, e.to_string()))?;
    let generated = write_project(&request.module, output, &shell, &backend, &request.write)?;
    Ok(GenerateResponse {
        files: written_files(&generated),
        warnings: generated.warnings,
        next_steps: vec![format!("cd {}", output.display()), "./orb-build.sh".to_string()],
    })
}

fn is_http_url(url: &str) -> bool {
    url::Url::parse(url).is_ok_and(|parsed| matches!(parsed.scheme(), "http" | "https") && parsed.host().is_some())
}
