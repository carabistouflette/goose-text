# Contributing

Keep the API small, pure, explicit and strict. Applications own I/O and resource
limits. Preserve byte-offset diagnostics, bounded decoding, caller-owned output,
and rejection before mutation. Prefer the standard library where its semantics
match. Do not add Unicode tables, native acceleration, normalization or other
text features without a concrete need and design review.

Use focused branches (`feat/...`, `fix/...`, `docs/...`) and Conventional Commits:
`feat: add ...`, `fix: reject ...`, `docs: clarify ...`, `test: cover ...`,
`chore: update ...`. Subjects are imperative; each commit contains one coherent
change. Commit tested milestones regularly. No stability guarantee before 1.0;
use semantic versions when a reviewed release is ready.

Behavior changes require public API regressions, independent review, and fixes
for actionable findings. Run `make format`, `make check test property`, and
`git diff --check`. Run security and GCC/Clang ASan/UBSan checks for validation
changes. Test malformed input, offset extremes, append failure atomicity and
integration in a consumer package. Keep CI passing. Never commit credentials,
generated compiler output or private workspace notes.

Pin a reviewed full upstream commit in `GOOSE_REVISION`; compiler changes require
full validation. Profile before optimizing, preserve safety contracts, run every
benchmark fixture, and retain raw samples plus compiler, hardware, flags and
source revision. Do not claim universal performance rankings. Report potential
vulnerabilities privately through GitHub advisory reporting when enabled.
