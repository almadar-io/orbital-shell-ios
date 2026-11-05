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
#[no_mangle]
pub extern "C" fn orbital_native_ios_main() {
    let language =
        std::fs::read_to_string(bundle_file("language.json")).expect("bundled language.json");
    orbital_core::language_data::install_language_bundle(&language)
        .expect("install language bundle");
    let program = std::fs::read_to_string(bundle_file("program.orb")).expect("bundled program.orb");
    orbital_client_dioxus::native::start(
        &program,
        orbital_client_dioxus::styles::stylesheets(),
        "Native TODO",
    )
    .expect("native TODO mount");
}
