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

## Baseline

The sources predate any linter, and a repository-wide cleanup is not something
this project does in one pass: rewriting working code to satisfy a readability
rule is the surest way to break what worked.

The baseline below is the count on the commit that introduced the linter. The
rule is **no new findings**, not zero findings. Code a change touches is brought
into line; the rest is left alone and migrates opportunistically.

| File | Findings at baseline |
|---|---|
| `autothemes.js` | 524 |
| `extension.js` | 579 |
| `prefs.js` | 486 |
| `quantize.js` | 159 |
| `stylesheets.js` | 742 |
| `utils.js` | 239 |
| **Total** | **2729** |

Update this table whenever a change moves the count, so it keeps describing the
repository rather than a state that has passed.
