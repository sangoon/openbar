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

Only `src/`, `package.json` (its `src/index.js` reads it at load time), `COPYING` and `REUSE.toml` are copied. Nothing here is modified; if
it ever needs a local change, record the change in this file.

## Resyncing

Fetch a newer commit the same way, replace `src/`, and update the commit and
date above. Re-run `npm run lint` and update the baseline in
`docs/development/linting.md` in the same commit, since the counts will move.
