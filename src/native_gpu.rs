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
    /// The app's reversed Google client id when it is built with a Firebase config: sign-in is compiled in.
    sign_in: Option<String>,
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
                sign_in: None,
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
            sign_in: None,
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
        for (placeholder, value) in sign_in_replacements(self.sign_in.as_deref()) {
            replacements.insert(placeholder, value);
        }
        crate::shell::replace_placeholders_in_dir(output, &replacements)?;
        for (target, library) in libraries {
            let destination = output.join("lib").join(target);
            std::fs::create_dir_all(&destination)?;
            std::fs::copy(library, destination.join(&contract.library))?;
        }
        Ok(())
    }
}

/// The project.yml fragments that compile sign-in in (Firebase Auth + GoogleSignIn, the plist, the URL scheme the
/// Google redirect returns on), or the stub that refuses every sign-in ask.
fn sign_in_replacements(reversed_client_id: Option<&str>) -> [(&'static str, String); 5] {
    match reversed_client_id {
        Some(scheme) => [
            ("{{SIGN_IN_PACKAGES}}", "packages:\n  Firebase:\n    url: https://github.com/firebase/firebase-ios-sdk\n    from: 11.6.0\n  GoogleSignIn:\n    url: https://github.com/google/GoogleSignIn-iOS\n    from: 8.0.0\n".to_string()),
            ("{{SIGN_IN_SOURCE}}", "OrbitalSignIn.m".to_string()),
            ("{{SIGN_IN_RESOURCES}}", "      - path: GoogleService-Info.plist\n        buildPhase: resources\n".to_string()),
            ("{{SIGN_IN_DEPENDENCIES}}", "    dependencies:\n      - package: Firebase\n        product: FirebaseCore\n      - package: Firebase\n        product: FirebaseAuth\n      - package: GoogleSignIn\n        product: GoogleSignIn\n".to_string()),
            ("{{SIGN_IN_URL_TYPES}}", format!("        CFBundleURLTypes:\n          - CFBundleURLSchemes:\n              - {scheme}\n")),
        ],
        None => [
            ("{{SIGN_IN_PACKAGES}}", String::new()),
            ("{{SIGN_IN_SOURCE}}", "OrbitalSignInOff.m".to_string()),
            ("{{SIGN_IN_RESOURCES}}", String::new()),
            ("{{SIGN_IN_DEPENDENCIES}}", String::new()),
            ("{{SIGN_IN_URL_TYPES}}", String::new()),
        ],
    }
}

/// The `REVERSED_CLIENT_ID` a GoogleService-Info.plist names: the URL scheme Google sign-in returns on.
pub fn reversed_client_id(plist: &str) -> Option<String> {
    let after_key = &plist[plist.find("<key>REVERSED_CLIENT_ID</key>")? + "<key>REVERSED_CLIENT_ID</key>".len()..];
    let start = after_key.find("<string>")? + "<string>".len();
    let end = after_key[start..].find("</string>")? + start;
    let value = after_key[start..end].trim();
    (!value.is_empty()).then(|| value.to_string())
}

impl NativeGpuShell {
    /// Compile sign-in in for an app whose Firebase config names `reversed_client_id`.
    pub fn with_sign_in(mut self, reversed_client_id: String) -> Self {
        self.sign_in = Some(reversed_client_id);
        self
    }
}

pub struct NativeGpuBackend {
    program: String,
    language: String,
    host: String,
    /// Each lazy page's program (EXEC-LOAD-2) and its file beside `program.orb`.
    lazy: Vec<(String, String)>,
    /// The remote files the app carries (`bundle-files.json`), which `orb` downloads beside it.
    bundled: String,
    /// The app's GoogleService-Info.plist, shipped as a resource when sign-in is compiled in.
    firebase_config: Option<String>,
}

impl NativeGpuBackend {
    pub fn new(
        schema: &OrbitalSchema,
        language: String,
        backend_url: Option<&str>,
        lazy: &[orbital_core_base::shell_protocol::LazyProgram],
    ) -> Result<Self, serde_json::Error> {
        let canonical = |schema: &OrbitalSchema| -> Result<String, serde_json::Error> {
            serde_json::to_string(&orbital_core_eval::util::canonical_json(&serde_json::to_value(schema)?))
        };
        let program = canonical(schema)?;
        let lazy = lazy
            .iter()
            .map(|page| Ok((page.orb_ref.clone(), canonical(&page.program)?)))
            .collect::<Result<Vec<_>, serde_json::Error>>()?;
        let bundled = orbital_core_base::native_bundle::BundledFiles::theme_fonts(schema);
        let host = match backend_url {
            Some(url) => serde_json::json!({ "mode": "server", "backendUrl": url }),
            None => serde_json::json!({ "mode": "embedded" }),
        };
        Ok(Self {
            program,
            language,
            host: serde_json::to_string(&host)?,
            lazy,
            bundled: serde_json::to_string(&bundled)?,
            firebase_config: None,
        })
    }

    /// Ship `plist` as the app's GoogleService-Info.plist.
    pub fn with_firebase_config(mut self, plist: String) -> Self {
        self.firebase_config = Some(plist);
        self
    }
}

impl Backend for NativeGpuBackend {
    fn name(&self) -> &'static str {
        "ios-native-gpu"
    }

    fn generate(&self, _module: &OirModule) -> GeneratedOutput {
        let mut files = vec![
            GeneratedFile::new("program.orb", self.program.clone()),
            GeneratedFile::new("language.json", self.language.clone()),
            GeneratedFile::new("native-host.json", self.host.clone()),
            GeneratedFile::new(orbital_core_base::native_bundle::BUNDLED_FILES, self.bundled.clone()),
        ];
        files.extend(self.lazy.iter().map(|(orb_ref, program)| GeneratedFile::new(orb_ref.clone(), program.clone())));
        if let Some(plist) = &self.firebase_config {
            files.push(GeneratedFile::new("GoogleService-Info.plist", plist.clone()));
        }
        GeneratedOutput { files, warnings: Vec::new() }
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
        assert!(project.contains("        UILaunchScreen: {}\n"), "a launch screen keeps iOS from letterboxing the app at a legacy size: {project}");
        assert!(contract.production_feature_set.contains("native-audio"), "control: the production library plays audio");
        for framework in ["AudioToolbox", "CoreAudio", "AVFoundation"] {
            assert!(project.contains(&format!("-framework {framework} ")), "native-audio links {framework}: {project}");
        }
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
            lazy: Vec::new(),
            bundled: r#"{"files":[]}"#.into(),
            firebase_config: None,
        };
        let files = backend.generate(&OirModule::new("test", "1.0.0")).files;
        assert_eq!(
            files.iter().map(|f| f.path.as_str()).collect::<Vec<_>>(),
            ["program.orb", "language.json", "native-host.json", "bundle-files.json"]
        );
        std::fs::remove_dir_all(root).unwrap();
    }

    /// An app built with a Firebase config compiles the real sign-in, its SDK packages, its plist and the reversed
    /// client id as its URL scheme; one built without compiles the stub and pulls no SDK.
    #[test]
    fn a_firebase_config_turns_the_projects_sign_in_on_and_its_absence_keeps_the_stub() {
        let contract = native_gpu_contract();
        let root = std::env::temp_dir().join(format!("orbital-ios-sign-in-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let package = root.join("package");
        write_bundle(&package, &contract.production_feature_set, b"!<arch>\nlibrary");
        crate::shell::copy_dir_recursive(
            &Path::new(env!("CARGO_MANIFEST_DIR")).join("renderers/native/template"),
            &package.join("templates/ios-native-gpu"),
        )
        .unwrap();
        let signed = root.join("signed");
        NativeGpuShell::from_package_root(&package)
            .with_sign_in("com.googleusercontent.apps.123-abc".into())
            .init_project(&signed, "signed")
            .unwrap();
        let project = std::fs::read_to_string(signed.join("project.yml")).unwrap();
        assert!(!project.contains("{{"), "every placeholder is filled: {project}");
        assert!(project.contains("- path: OrbitalSignIn.m"), "{project}");
        assert!(project.contains("https://github.com/firebase/firebase-ios-sdk") && project.contains("product: FirebaseAuth"), "{project}");
        assert!(project.contains("product: GoogleSignIn"), "{project}");
        assert!(project.contains("- path: GoogleService-Info.plist"), "{project}");
        assert!(project.contains("com.googleusercontent.apps.123-abc"), "{project}");
        let plain = root.join("plain");
        NativeGpuShell::from_package_root(&package).init_project(&plain, "plain").unwrap();
        let project = std::fs::read_to_string(plain.join("project.yml")).unwrap();
        assert!(!project.contains("{{"), "control: every placeholder is filled: {project}");
        assert!(project.contains("- path: OrbitalSignInOff.m") && !project.contains("packages:") && !project.contains("GoogleService-Info.plist"), "control: no config, no SDK: {project}");
        std::fs::remove_dir_all(root).unwrap();
    }

    /// Lazy pages ship beside `program.orb` and the theme's font files are listed for `orb` to download, as the
    /// Android shell does; the project copies both folders into the app when they exist.
    #[test]
    fn lazy_pages_and_carried_fonts_ship_in_the_bundle_and_the_project_copies_them() {
        let program = |type_scale: &str, page: &str| -> OrbitalSchema {
            orbital_core_base::json_value::from_json_str::<OrbitalSchema>(&format!(
                r#"{{"name":"App","typeContractVersion":1,"theme":{{"name":"t","tokens":{{"typeScale":{type_scale}}}}},"orbitals":[{{"name":"Home","entity":{{"name":"Row","fields":[{{"name":"id","type":"string"}}]}},"traits":[],"pages":[{{"name":"{page}","path":"/","traits":[]}}]}}]}}"#
            ))
            .unwrap()
        };
        let home = program(r#"{"bodyFile":"https://fonts.test/Body.ttf"}"#, "HomePage");
        let lazy = vec![orbital_core_base::shell_protocol::LazyProgram { orb_ref: "lazy/BlogEN.orb".into(), program: program("{}", "BlogPage") }];
        let files = NativeGpuBackend::new(&home, "{}".into(), None, &lazy).unwrap().generate(&OirModule::new("test", "1.0.0")).files;
        assert!(files.iter().any(|f| f.path == "lazy/BlogEN.orb" && f.content.contains("BlogPage")));
        let listed = files.iter().find(|f| f.path == "bundle-files.json").expect("bundle-files.json");
        let listed: orbital_core_base::native_bundle::BundledFiles = orbital_core_base::json_value::from_json_str(&listed.content).unwrap();
        assert_eq!(listed.files.iter().map(|f| (f.url.as_str(), f.path.as_str())).collect::<Vec<_>>(), [("https://fonts.test/Body.ttf", "fonts/0")]);
        let plain = NativeGpuBackend::new(&program("{}", "HomePage"), "{}".into(), None, &[]).unwrap().generate(&OirModule::new("test", "1.0.0")).files;
        assert_eq!(plain.len(), 4, "control: no lazy page, no font file, the four bundle files");
        let project = std::fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join("renderers/native/template/project.yml")).unwrap();
        for folder in ["lazy", "fonts"] {
            assert!(project.contains(&format!("- path: {folder}\n        type: folder\n        optional: true\n        buildPhase: resources")), "{folder}: {project}");
        }
        assert!(project.contains("- path: bundle-files.json\n        buildPhase: resources"), "{project}");
        let build = std::fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join("renderers/native/template/orb-build.sh")).unwrap();
        let made = build.find("mkdir -p lazy fonts").expect("an app with no lazy page or font file still has both folders Xcode copies");
        assert!(made < build.find("xcodegen generate").unwrap(), "the folders exist before the project is generated: {build}");
    }

    #[test]
    fn the_reversed_client_id_is_read_from_the_plist() {
        let plist = "<plist><dict><key>CLIENT_ID</key><string>1-a.apps.googleusercontent.com</string><key>REVERSED_CLIENT_ID</key>\n\t<string>com.googleusercontent.apps.1-a</string></dict></plist>";
        assert_eq!(reversed_client_id(plist).as_deref(), Some("com.googleusercontent.apps.1-a"));
        assert_eq!(reversed_client_id("<plist><dict></dict></plist>"), None, "control: no key, no scheme");
    }
}
