<div align="center">

# orbital-shell-ios

**The native iOS shell: generates an Xcode project (SwiftUI) from a compiled Orbital program.**

[![CI](https://github.com/almadar-io/orbital-shell-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/almadar-io/orbital-shell-ios/actions/workflows/ci.yml) [![License: BUSL-1.1](https://img.shields.io/badge/license-BUSL--1.1-blue)](LICENSE)

</div>

<p align="center"><sub>Part of <a href="https://github.com/almadar-io/orb"><b>Orb</b></a>: the language where the rule is the program. <a href="https://orb.almadar.io">orb.almadar.io</a></sub></p>

The iOS shell turns a compiled Orbital program into a SwiftUI app project. It carries the iOS project template and the generated SwiftUI renderer pack, and links the Almadar kernel and canvas as a static library.

## Where this fits

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/almadar-io/orb/main/static/img/readme/architecture/orbital-shell-ios-dark.svg">
  <img src="https://raw.githubusercontent.com/almadar-io/orb/main/static/img/readme/architecture/orbital-shell-ios-light.svg" width="100%" alt="Where orbital-shell-ios sits in the Almadar architecture">
</picture>

| Upstream (this repo depends on) | Downstream (depends on this repo) |
|---|---|
| [orbital-core](https://github.com/almadar-io/orbital-core): IR, evaluator and kernel (`orbital-core-base`, `orbital-core-eval`) | [orbital-cli](https://github.com/almadar-io/orbital-cli): the `orb` binary, which runs this shell as `orb-shell-ios` for `orb compile --shell ios` |
| [orbital-canvas](https://github.com/almadar-io/orbital-canvas): 2D/3D render primitives |  |
| [orbital-ffi](https://github.com/almadar-io/orbital-ffi): the C ABI library the generated app links (dev-dependency here) |  |

## Quick start

Build the kernel library once, from the `orbital-rust` workspace, then generate and build the app:

```bash
make ios-lib            # in orbital-rust: builds liborbital_ffi.a for aarch64-apple-ios-sim
orb compile <program.orb> --shell ios -o <out-dir>
cd <out-dir> && CARGO_BUILD_DIR=<orbital-rust>/target ./orb-build.sh
```

`make ios-lib-device` builds the device library (`aarch64-apple-ios`). In `orbital-rust`, `make ios-run ORB=<program.orb> OUT=<dir>` runs the compile and `orb-build.sh --run` together.

## How `orb compile --shell ios` uses it

`orb` runs the `orb-shell-ios` program. It needs the resolved program and the installed `swiftui` renderer pack, copies `templates/ios-shell` (`project.yml`, `Info.plist`, `Sources/`, `orb-build.sh`), and generates the Swift sources; it then validates the project structure and layout. The next step it reports is `./orb-build.sh`.

The generated app runs the same kernel as every other host, through `orbital-ffi`: `orb-build.sh` requires `CARGO_BUILD_DIR` to point at the Cargo target directory holding `aarch64-apple-ios-sim/release/liborbital_ffi.a`, which `make ios-lib` in `orbital-rust` produces (and checks for the kernel and canvas symbols).

## Layout

| Path | Contents |
|---|---|
| `src/` | The crate: backend, pack, shell, `orb-shell-ios` program |
| `templates/ios-shell/` | Xcode project scaffold |
| `renderers/swiftui/` | Generated SwiftUI renderer sources and pattern fixtures. Generated: fix the template or generator, not the output |
| `hosts/`, `runtime/`, `core/` | Swift templates (`APIClient`, `OrbitalViewModel`, `AwaitRenders`, `EffectHandlers`, `AnyCodable`) |
| `tests/` | Pack layout, renderer coverage, slot-role parity, kernel-bridge symbol coverage, `device-bench/` |

## Development

The crate reads the Almadar language data (patterns, operators, themes, vocabularies) from the installed npm packages, so install those first (this is the CI recipe):

```bash
npm install --no-save --no-package-lock @almadar/core@^10 @almadar/std@^16 @almadar/lolo-ar@^1 @almadar/lolo-sl@^1
cargo test
```

Open gaps are tracked in [Almadar_Gaps.md](Almadar_Gaps.md). Work on `main`; never create a feature branch.

CI also runs `node renderers/swiftui/scripts/check-pack.mjs` before `cargo test`.

## Docs

- [Orb documentation](https://orb.almadar.io/docs): the language, the `orb` CLI and how the pieces fit

## License

[Business Source License 1.1](LICENSE): free for non-commercial and evaluation use; converts to Apache-2.0 on the change date.
