<!-- Gap ledger for this repo: the source of truth for its open gaps. -->
# orbital-shell-ios — open gaps

Every open gap this repo owns lives here. This file is the source of truth; the monorepo's `docs/Almadar_Gaps.md` only rolls it up.

- **One entry per gap:** `- **<code>** — <what is wrong and where>. <owning package> [mechanical|architectural] — <evidence, prevention rung>`.
- **Codes:** new gaps use this repo's prefix `G-ORBITAL-SHELL-IOS-`. Take the "Next code" below, then bump it in the same edit. Codes are never reused or renamed.
- **Close by deleting.** Remove the entry in the same commit as the fix.

Next code: `G-ORBITAL-SHELL-IOS-004`
- **G-ORBITAL-SHELL-IOS-002** — A bounded inner scroll area in the SwiftUI renderer takes the full page height when its content is short, while Compose and web fit it to its content; owner ruling 2026-11-08: SwiftUI fits to content and stops growing at the page height. orbital-shell-ios [mechanical] — Reproduce: kflow (std-kflow-dev) `--shell ios` on the simulator, any page with a short inner scroll list shows empty space below it. Prevention rung: (3) the verifiers (structure parity against the kernel render facts, G-CROSS-493). Root cause: one-off.
- **G-ORBITAL-SHELL-IOS-003** — SwiftUI icons render much smaller than on Compose and web: kflow-landing's subjects strip and its four step-card icons draw at roughly a third of the Compose size. orbital-shell-ios (`renderers/swiftui` icon atom sizing) [mechanical] — Reproduce: kflow `--shell ios` on the simulator next to `--shell android` on the emulator, scroll to "Sixteen subjects" (2026-11-09). Prevention rung: (3) the verifiers (structure parity compares icon frames). Root cause: one-off.

