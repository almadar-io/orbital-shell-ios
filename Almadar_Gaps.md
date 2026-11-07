<!-- Gap ledger for this repo: the source of truth for its open gaps. -->
# orbital-shell-ios — open gaps

Every open gap this repo owns lives here. This file is the source of truth; the monorepo's `docs/Almadar_Gaps.md` only rolls it up.

- **One entry per gap:** `- **<code>** — <what is wrong and where>. <owning package> [mechanical|architectural] — <evidence, prevention rung>`.
- **Codes:** new gaps use this repo's prefix `G-ORBITAL-SHELL-IOS-`. Take the "Next code" below, then bump it in the same edit. Codes are never reused or renamed.
- **Close by deleting.** Remove the entry in the same commit as the fix.

Next code: `G-ORBITAL-SHELL-IOS-002`

- **G-ORBITAL-SHELL-IOS-001** — The Swift backend (`src/backend.rs`) emits recursive named types by value, so swiftc refuses them: a struct whose field is an optional of itself (`StdAgentToolLoopLlmSchema.items : StdAgentToolLoopLlmSchema?`, and the 45 `…AgentTurn{Binding,Table}Parameters` copies) is "a value type with infinite size", and a recursive union (`StdFirestoreRowPredicate`) is "a recursive enum not marked indirect". It blocks kflow's SwiftUI build (47 errors, `orb-dev compile std-kflow-dev.lolo --shell ios`, then `xcodebuild`). Fix in tree (uncommitted): a union whose arm reaches its own declaration by value is an `indirect enum`, and a struct or entity field that does so is boxed in `Indirect<T>` (`core/Indirect.swift`); arrays and dictionaries are heap storage and stay as they are. Unit tests and a swiftc round trip pass. It closes once the kflow SwiftUI build is green; that build is waiting on kflow validating 0/0 after the optional-into-required corpus migration. orbital-shell-ios [mechanical] — prevention rung (3): a native build of an app organism (G-CROSS-494). Root cause: one-off.
