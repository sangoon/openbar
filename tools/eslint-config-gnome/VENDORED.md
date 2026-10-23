# Vendored: eslint-config-gnome

Upstream: https://gitlab.gnome.org/World/javascript/eslint-config-gnome
Commit: c479d059e8d9ea99c3b53c2ea43abf7fdb05eb51 (2025-06-17)
Version: 1.0.0
Licence: MIT OR LGPL-2.1-or-later, see COPYING

This is the same commit GNOME Shell 51.1 pins in its own `tools/package.json`,
so this repository lints its JavaScript with the configuration the Shell applies
to its own.

It is vendored rather than depended on because the package is not published on
npm, and npm 12 refuses git dependencies (`EALLOWGIT`) and remote tarballs
(`EALLOWREMOTE`) by default. Depending on it would have meant relaxing that
default for the whole repository, including for anyone who clones it.

Only `src/`, `package.json` (its `src/index.js` reads it at load time),
`COPYING` and `REUSE.toml` are copied. Nothing here is modified; if it ever
needs a local change, record the change in this file.

## Resyncing

Fetch a newer commit the same way, replace both `src/` and `package.json` —
`src/index.js` reads the version out of `package.json` at load time, so a stale
one misreports it — and update the commit and date above. Re-run
`npm run lint` and update the baseline in `docs/development/linting.md` in the
same commit, since the counts will move.

## Dependency versions: declared upstream versus resolved here

Upstream's `package.json` (vendored beside `src/`) declares `@eslint/js ^9.28.0`,
`@eslint/config-helpers ^0.2.2` and `eslint-plugin-jsdoc ^48.11.0`, which implies
ESLint 9. This repository resolves newer majors: `eslint ^10.13.0`,
`@eslint/js ^10.0.1`, `@eslint/config-helpers ^0.5.0` and
`eslint-plugin-jsdoc ^62.0.0` (exact versions in `package-lock.json`).

The baseline in `docs/development/linting.md` therefore comes from ESLint 10, not
from the versions upstream declares. Measured against the declared ranges
(`eslint 9.39.5`, `@eslint/js 9.39.5`, `config-helpers 0.2.3`, `jsdoc 48.11.0`)
the total is 2719 instead of 2729. The only rule that differs is
`no-useless-assignment`, which ESLint 10 adds to `js/recommended` and which
reports 10 findings here.
