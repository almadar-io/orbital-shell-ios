#[cfg(target_os = "ios")]
fn bundle_file(name: &str) -> std::path::PathBuf {
    std::env::current_exe()
        .expect("iOS executable")
        .parent()
        .expect("iOS app bundle")
        .join(name)
}

#[cfg(target_os = "ios")]
#[no_mangle]
pub extern "C" fn orbital_native_ios_set_reduced_motion(reduced: bool) {
    orbital_client_dioxus::native::set_reduced_motion(reduced);
}

#[cfg(target_os = "ios")]
#[derive(serde::Deserialize)]
#[serde(tag = "mode", rename_all = "kebab-case", deny_unknown_fields)]
enum NativeHost {
    Embedded,
    Server {
        #[serde(rename = "backendUrl")]
        backend_url: String,
    },
}

#[cfg(target_os = "ios")]
#[no_mangle]
pub extern "C" fn orbital_native_ios_main() {
    let language =
        std::fs::read_to_string(bundle_file("language.json")).expect("bundled language.json");
    orbital_core::language_data::install_language_bundle(&language)
        .expect("install language bundle");
    let program = std::fs::read_to_string(bundle_file("program.orb")).expect("bundled program.orb");
    let host: NativeHost = serde_json::from_str(
        &std::fs::read_to_string(bundle_file("native-host.json")).expect("bundled native-host.json"),
    )
    .expect("native-host.json contract");
    match host {
        NativeHost::Embedded => orbital_client_dioxus::native::start(
            &program,
            orbital_client_dioxus::styles::stylesheets(),
            "Native App",
        ),
        NativeHost::Server { backend_url } => orbital_client_dioxus::native::start_server(
            &program,
            &backend_url,
            orbital_client_dioxus::styles::stylesheets(),
            "Native App",
        ),
    }
    .expect("native GPU mount");
}
