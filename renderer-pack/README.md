# almadar-renderers-ios

The Almadar native **ios** renderer pack: the generated renderer sources (`renderers/`) and the
per-pattern conformance fixtures (`fixtures/`) that `orb` emits into every ios app.

- **Generated, never hand-edited.** `almadar-pattern-sync` writes everything here (`ios-renderers`,
  `icon-map`, `native-theme`, `pattern-fixtures`) from the installed `@almadar/core` pattern
  registry and its Swift/Kotlin templates. Fix the template or the generator, then regenerate.
- **Not published.** Like the shell templates, the pack is a submodule of `orbital-rust`
  (`templates/almadar-renderers-ios`) and ships beside each `orb` release; `orb` reads it from disk
  at emit, so a renderer change is a submodule bump, never a compiler rebuild.
- **Contract.** `package.json` → `orbRenderer`: `target`, `rendererInterface` (the shell refuses
  any other), `patternsRegistry` (the core version generated from), `coverage` (patterns this pack
  renders; anything else gets the declared unsupported-pattern answer), `sources`, `fixtures`.

`node scripts/check-pack.mjs` runs the consistency check CI runs.
