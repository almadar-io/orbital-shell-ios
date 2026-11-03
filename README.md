<div align="center">

# orbital-shell-ios

**The native iOS shell: generates an Xcode project (SwiftUI) from a compiled Orbital program.**

[![CI](https://github.com/almadar-io/orbital-shell-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/almadar-io/orbital-shell-ios/actions/workflows/ci.yml) [![License: BUSL-1.1](https://img.shields.io/badge/license-BUSL--1.1-blue)](LICENSE)

</div>

The iOS shell turns a compiled Orbital program into a SwiftUI app project. It carries the iOS project template and the generated SwiftUI renderer pack, and links the Almadar kernel and canvas as a static library.

## Where this fits

```mermaid
flowchart TB
  subgraph kernel["Kernel and substrate"]
    core["orbital-core<br/>IR · evaluator · kernel"]
    canvas["orbital-canvas<br/>2D/3D render primitives"]
  end
  subgraph lang["Language"]
    lolo["orbital-lolo<br/>.lolo → .orb"]
    compiler["orbital-compiler<br/>validate · codegen"]
  end
  subgraph hosts["Shells and hosts"]
    ts["orbital-shell-typescript<br/>web · node · @almadar/core"]
    rs["orbital-shell-rust<br/>desktop · tui"]
    py["orbital-shell-python"]
    ios["orbital-shell-ios"]
    android["orbital-shell-android"]
    os["orbital-shell-os"]
    wasm["orbital-wasm<br/>browser kernel"]
    ffi["orbital-ffi<br/>C ABI for mobile"]
    router["orbital-router"]
  end
  cli["orbital-cli<br/>the orb binary"]
  ws["orbital-rust<br/>workspace · cross-crate tests"]
  dist["orb<br/>npm · releases"]
  subgraph pkgs["Language packages"]
    std["almadar-std<br/>@almadar/std substrate"]
    beh["behaviors<br/>themed organisms"]
    langs["lolo-ar · lolo-sl<br/>language packs"]
  end
  subgraph apps["Apps and sites"]
    builder["builder (studio)"]
    kflow["kflow-academy"]
    nata["nata"]
    rawi["rawi"]
    site["almadar (websites)"]
  end
  core --> lolo & compiler & ts & rs & py & ios & android & os & wasm & ffi & router
  canvas --> ts & rs & ffi
  lolo --> compiler
  compiler --> cli
  ts & rs & py & ios & android & os --> cli
  cli --> dist
  ws -.pins.-> core & lolo & compiler & cli
  dist --> std
  std --> beh
  std --> langs
  beh --> builder & kflow & nata & rawi & site
  click core "https://github.com/almadar-io/orbital-core"
  click canvas "https://github.com/almadar-io/orbital-canvas"
  click lolo "https://github.com/almadar-io/orbital-lolo"
  click compiler "https://github.com/almadar-io/orbital-compiler"
  click ts "https://github.com/almadar-io/orbital-shell-typescript"
  click rs "https://github.com/almadar-io/orbital-shell-rust"
  click py "https://github.com/almadar-io/orbital-shell-python"
  click ios "https://github.com/almadar-io/orbital-shell-ios"
  click android "https://github.com/almadar-io/orbital-shell-android"
  click os "https://github.com/almadar-io/orbital-shell-os"
  click wasm "https://github.com/almadar-io/orbital-wasm"
  click ffi "https://github.com/almadar-io/orbital-ffi"
  click router "https://github.com/almadar-io/orbital-router"
  click cli "https://github.com/almadar-io/orbital-cli"
  click ws "https://github.com/almadar-io/orbital-rust"
  click dist "https://github.com/almadar-io/orb"
  click std "https://github.com/almadar-io/almadar-std"
  click beh "https://github.com/almadar-io/behaviors"
  click langs "https://github.com/almadar-io/lolo-ar"
  click builder "https://github.com/itechdom/almadar-studio"
  click kflow "https://github.com/almadar-io/almadar-kflow-academy"
  click nata "https://github.com/almadar-io/almadar-nata"
  click rawi "https://github.com/almadar-io/almadar-rawi"
  click site "https://github.com/almadar-io/almadar"
  classDef here fill:#2563eb,color:#fff,stroke:#1e40af,stroke-width:3px
  class ios here
```

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

- [Almadar_Orbital_Shell_iOS.md](https://github.com/itechdom/kflow.ai/blob/main/docs/Almadar_Orbital_Shell_iOS.md)
- [Almadar_Execution_Semantics.md](https://github.com/itechdom/kflow.ai/blob/main/docs/Almadar_Execution_Semantics.md)

## License

[Business Source License 1.1](LICENSE): free for non-commercial and evaluation use; converts to Apache-2.0 on the change date.
