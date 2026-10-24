# Linting

    npm install
    npm run lint

The configuration is `eslint-config-gnome`, the same one GNOME Shell applies to
its own JavaScript — the same commit, in fact, as the one gnome-shell 51.1 pins.

It lives in the repository under `tools/eslint-config-gnome/` rather than in
`node_modules`, because it is not published on npm and npm 12 refuses both git
dependencies and remote tarballs by default. `tools/eslint-config-gnome/VENDORED.md`
records the commit, the licence, and how to resync it.

Only `configs.recommended` is applied. `configs.jsdoc` would demand doc comments
on code this project does not rewrite.

## Reach

`npm run lint` covers `openbar@neuromorph`, `eslint.config.js` and
`tools/harness`. The first is upstream's code, carried under a baseline; the
other two are JavaScript this fork wrote, so "no new findings" binds them to
zero rather than to a baseline.

`tools/eslint-config-gnome/` is deliberately outside the reach: it is vendored
byte-for-byte from upstream and linting it would measure someone else's
repository.

## Baseline

The sources predate any linter, and a repository-wide cleanup is not something
this project does in one pass: rewriting working code to satisfy a readability
rule is the surest way to break what worked.

The baseline below is the count on the commit that introduced the linter. The
rule is **no new findings**, not zero findings. Code a change touches is brought
into line; the rest is left alone and migrates opportunistically.

| File | Findings at baseline |
|---|---|
| `openbar@neuromorph/autothemes.js` | 524 |
| `openbar@neuromorph/extension.js` | 579 |
| `openbar@neuromorph/prefs.js` | 486 |
| `openbar@neuromorph/quantize.js` | 159 |
| `openbar@neuromorph/stylesheets.js` | 742 |
| `openbar@neuromorph/utils.js` | 239 |
| `eslint.config.js` | 0 |
| `tools/harness/unsafemode@local/extension.js` | 0 |
| **Total** | **2729** |

The two zeros are measured, not assumed: both files appear in
`npm run lint -- --format json` with an error count, and a deliberately
non-conforming file dropped into `tools/harness/` raised the total to 2731. A
zero that has never been seen to move is not a measurement.

`tools/eslint-config-gnome/VENDORED.md` records the caveat behind these
numbers: they were measured under ESLint 10, which enables
`no-useless-assignment`, and the versions upstream's `package.json` declares
give 2719 instead.

Update this table whenever a change moves the count, so it keeps describing the
repository rather than a state that has passed.
