use orbital_core_base::generate::{Backend, GeneratedFile, GeneratedOutput};
use orbital_core_base::ir::OirModule;
use orbital_core_base::schema::OrbitalSchema;
use orbital_core_base::shell::{Shell, ShellError};
use serde::Deserialize;
use std::path::{Path, PathBuf};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct NativeGpuContract {
    contract_version: u32,
    targets: Vec<String>,
    library: String,
    min_ios: String,
    production_feature_set: String,
    research_feature_set: String,
}

fn native_gpu_contract() -> NativeGpuContract {
    serde_json::from_str(include_str!("../renderers/native/contract.json"))
        .expect("the bundled native GPU contract must be valid")
}

/// An iOS static library is an `ar` archive.
fn is_static_archive(header: &[u8]) -> bool {
    header.starts_with(b"!<arch>\n")
}

pub struct NativeGpuShell {
    template: PathBuf,
    bundle: PathBuf,
    research: bool,
}

impl NativeGpuShell {
    pub fn new() -> Result<Self, ShellError> {
        let research = match std::env::var("ORBITAL_NATIVE_GPU_RESEARCH") {
            Ok(value) if value == "1" => true,
            Ok(_) => {
                return Err(ShellError::Template(
                    "ORBITAL_NATIVE_GPU_RESEARCH must be 1 when set".into(),
                ))
            }
            Err(std::env::VarError::NotPresent) => false,
            Err(error) => return Err(ShellError::Template(error.to_string())),
        };
        if let Some(bundle) = std::env::var_os("ORBITAL_NATIVE_GPU_LIB_DIR") {
            return Ok(Self {
                template: Path::new(env!("CARGO_MANIFEST_DIR")).join("renderers/native/template"),
                bundle: PathBuf::from(bundle),
                research,
            });
        }
        let executable = std::env::current_exe()?;
        let package = executable.parent().and_then(Path::parent).ok_or_else(|| {
            ShellError::NotFound(format!(
                "native GPU shell package beside {}",
                executable.display()
            ))
        })?;
        let mut shell = Self::from_package_root(package);
        shell.research = research;
        Ok(shell)
    }

    fn from_package_root(package: &Path) -> Self {
        Self {
            template: package.join("templates/ios-native-gpu"),
            bundle: package.join("native-gpu/ios"),
            research: false,
        }
    }

    fn verified_libraries(&self) -> Result<Vec<(String, PathBuf)>, ShellError> {
        let contract = native_gpu_contract();
        let feature_set = if self.research {
            &contract.research_feature_set
        } else {
            &contract.production_feature_set
        };
        let targets: Vec<&str> = contract.targets.iter().map(String::as_str).collect();
        let expected = orbital_core_base::native_bundle::NativeBundleExpectation {
            contract_version: contract.contract_version,
            shell_version: env!("CARGO_PKG_VERSION"),
            feature_set,
            library: &contract.library,
            targets: &targets,
        };
        orbital_core_base::native_bundle::verified_libraries(&self.bundle, &expected, is_static_archive)
            .map_err(|e| ShellError::Template(e.to_string()))
    }
}

impl Shell for NativeGpuShell {
    fn name(&self) -> &'static str {
        "ios-native-gpu"
    }
    fn description(&self) -> &'static str {
        "iOS app with the shared Dioxus native GPU renderer"
    }
    fn extensions(&self) -> &[&'static str] {
        &["c", "m"]
    }
    fn template_path(&self) -> &Path {
        &self.template
    }
    fn generated_dir(&self) -> &str {
        "."
    }
    fn build_command(&self) -> &str {
        "./orb-build.sh"
    }
    fn dev_command(&self) -> &str {
        "./orb-build.sh --run"
    }
    fn test_command(&self) -> &str {
        "./orb-build.sh"
    }

    fn validate_structure(&self, output: &Path) -> Result<(), ShellError> {
        for file in ["project.yml", "main.c", "orb-build.sh"] {
            if !output.join(file).is_file() {
                return Err(ShellError::InvalidStructure {
                    path: output.join(file),
                    message: format!("Missing required file: {file}"),
                });
            }
        }
        Ok(())
    }

    fn copy_template(&self, output: &Path) -> Result<(), ShellError> {
        if !self.template.is_dir() {
            return Err(ShellError::NotFound(self.template.display().to_string()));
        }
        crate::shell::copy_dir_recursive(&self.template, output)?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let file = output.join("orb-build.sh");
            let mut permissions = std::fs::metadata(&file)?.permissions();
            permissions.set_mode(permissions.mode() | 0o111);
            std::fs::set_permissions(file, permissions)?;
        }
        Ok(())
    }

    fn init_project(&self, output: &Path, project_name: &str) -> Result<(), ShellError> {
        let libraries = self.verified_libraries()?;
        let contract = native_gpu_contract();
        self.copy_template(output)?;
        let mut replacements = crate::shell::build_replacements(project_name);
        replacements.insert("{{NATIVE_GPU_MIN_IOS}}", contract.min_ios.clone());
        replacements.insert("{{NATIVE_GPU_LIBRARY}}", contract.library.clone());
        crate::shell::replace_placeholders_in_dir(output, &replacements)?;
        for (target, library) in libraries {
            let destination = output.join("lib").join(target);
            std::fs::create_dir_all(&destination)?;
            std::fs::copy(library, destination.join(&contract.library))?;
        }
        Ok(())
    }
}

pub struct NativeGpuBackend {
    program: String,
    language: String,
    host: String,
}

impl NativeGpuBackend {
    pub fn new(
        schema: &OrbitalSchema,
        language: String,
        backend_url: Option<&str>,
    ) -> Result<Self, serde_json::Error> {
        let value = serde_json::to_value(schema)?;
        let program = serde_json::to_string(&orbital_core_eval::util::canonical_json(&value))?;
        let host = match backend_url {
            Some(url) => serde_json::json!({ "mode": "server", "backendUrl": url }),
            None => serde_json::json!({ "mode": "embedded" }),
        };
        Ok(Self {
            program,
            language,
            host: serde_json::to_string(&host)?,
        })
    }
}

impl Backend for NativeGpuBackend {
    fn name(&self) -> &'static str {
        "ios-native-gpu"
    }

    fn generate(&self, _module: &OirModule) -> GeneratedOutput {
        GeneratedOutput {
            files: vec![
                GeneratedFile::new("program.orb", self.program.clone()),
                GeneratedFile::new("language.json", self.language.clone()),
                GeneratedFile::new("native-host.json", self.host.clone()),
            ],
            warnings: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write_bundle(package: &Path, feature_set: &str, body: &[u8]) {
        let contract = native_gpu_contract();
        let bundle = package.join("native-gpu/ios");
        let mut libraries = serde_json::Map::new();
        for target in &contract.targets {
            let dir = bundle.join(target);
            std::fs::create_dir_all(&dir).unwrap();
            std::fs::write(dir.join(&contract.library), body).unwrap();
            libraries.insert(
                target.clone(),
                serde_json::json!(orbital_core_base::native_bundle::file_sha256(&dir.join(&contract.library)).unwrap()),
            );
        }
        let manifest = serde_json::json!({
            "contractVersion": contract.contract_version,
            "shellVersion": env!("CARGO_PKG_VERSION"),
            "featureSet": feature_set,
            "libraries": libraries,
        });
        std::fs::write(bundle.join("manifest.json"), manifest.to_string()).unwrap();
    }

    #[test]
    fn native_gpu_project_links_each_target_library_and_names_the_app() {
        let contract = native_gpu_contract();
        let root = std::env::temp_dir().join(format!("orbital-ios-native-gpu-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let package = root.join("package");
        write_bundle(&package, &contract.production_feature_set, b"!<arch>\nlibrary");
        crate::shell::copy_dir_recursive(
            &Path::new(env!("CARGO_MANIFEST_DIR")).join("renderers/native/template"),
            &package.join("templates/ios-native-gpu"),
        )
        .unwrap();
        let app = root.join("todo-app");
        let shell = NativeGpuShell::from_package_root(&package);
        shell.init_project(&app, "todo-app").unwrap();
        let project = std::fs::read_to_string(app.join("project.yml")).unwrap();
        assert!(project.contains("name: todo_app"), "{project}");
        assert!(project.contains("PRODUCT_BUNDLE_IDENTIFIER: com.orbital.todo_app"), "{project}");
        assert!(project.contains(&format!("deploymentTarget: \"{}\"", contract.min_ios)), "{project}");
        assert!(project.contains(&format!("$(PROJECT_DIR)/lib/aarch64-apple-ios-sim/{}", contract.library)), "{project}");
        assert!(!project.contains("{{"), "every placeholder is filled: {project}");
        for target in &contract.targets {
            assert_eq!(std::fs::read(app.join("lib").join(target).join(&contract.library)).unwrap(), b"!<arch>\nlibrary");
        }
        assert!(app.join("main.c").is_file() && app.join("orb-build.sh").is_file());

        write_bundle(&package, &contract.research_feature_set, b"!<arch>\nlibrary");
        assert!(shell.verified_libraries().is_err(), "a research bundle is refused by a production compile");
        let mut research = NativeGpuShell::from_package_root(&package);
        research.research = true;
        assert!(research.verified_libraries().is_ok());
        write_bundle(&package, &contract.production_feature_set, b"\x7fELF not an archive");
        assert!(shell.verified_libraries().is_err(), "control: a non-archive library is refused");

        let backend = NativeGpuBackend {
            program: "{}".into(),
            language: "{}".into(),
            host: r#"{"mode":"embedded"}"#.into(),
        };
        let files = backend.generate(&OirModule::new("test", "1.0.0")).files;
        assert_eq!(
            files.iter().map(|f| f.path.as_str()).collect::<Vec<_>>(),
            ["program.orb", "language.json", "native-host.json"]
        );
        std::fs::remove_dir_all(root).unwrap();
    }
}
