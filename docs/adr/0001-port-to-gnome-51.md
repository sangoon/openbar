# 1. Port Open Bar to GNOME Shell 50 and 51 in this fork

Date: 2026-10-23

## Status

Accepted.

## Context

Upstream `neuromorph/openbar` has published nothing to git since 2025-10-05.
extensions.gnome.org advertises Shell versions 42 through 49. GNOME 50 and 51
are unsupported anywhere, and GNOME 51 is what this fork's maintainer runs.

Upstream's `main` is also broken, and not only on new Shells. `clearBtn` was
declared in two block scopes and read outside both, so `enable()` threw on every
Shell version and the extension reached state 3 `ERROR`. The fix exists in the
version 49 payload on extensions.gnome.org and was never pushed to git: the
released extension is newer than `main`.

Two more defects, both silent and both older than GNOME 51, sat behind it: the
Clear button was read at child index 1 of a box that holds one child, and the
date menu traversal looked for a `_list` property that stopped existing in
GNOME 49.

The sources are GPL-2.0-or-later, so forking and redistributing is permitted
provided the licence and the existing copyright notices are kept and
modifications are stated.

## Decision

Maintain the port in this fork, and offer it upstream as two separate pull
requests: the `clearBtn` fix first, since it stands alone and repairs every
version, then GNOME 50 and 51 support.

Keep the scope to compatibility. These are known and deliberately left alone:

- The group chrome that GNOME 49+ added to notification groups
  (`message-notification-group`, `message-group-header`, `message-group-title`,
  `message-collapse-button`) has no rule in `stylesheets.js`. Notifications
  theme correctly; the group header and collapse button do not. This is theming
  design, tracked separately, and not folded into a port offered upstream.
- The six GTK widgets deprecated since 4.10 in `prefs.js` still work in GTK
  4.24 and will break at GTK 5. Replacing them is an interface rewrite.
- The sources keep upstream's comments and file sizes. Only code the port
  touches follows the maintainer's conventions.

Verify against a real Shell, not by reading. `tools/verify-headless.sh` starts a
throwaway headless Shell and reports the state the Shell itself assigns the
extension (see `docs/development/testing.md`).

Resolve the actors to theme by style class, not by tree position, because every
stylesheet rule is the compound selector `.openmenu.message`: a class on the
wrong actor matches nothing while still looking like success to a probe that only
asks whether some actor received a class. Guard the date menu traversal so
drift in the Shell's structure degrades theming instead of putting the extension
in `ERROR`. One guard covers both panes, so a message-pane drift also costs the
calendar pane its theming; that is a recorded trade-off
(`docs/development/message-list-structure.md`).

Lint with `eslint-config-gnome` vendored under `tools/eslint-config-gnome/`
rather than declared as a dependency. The package is not on npm, and npm 12
refuses git dependencies and remote tarballs by default; depending on it would
mean relaxing a security default for everyone who clones. The vendored commit is
the one GNOME Shell 51.1 pins. The rule is no new findings against a recorded
baseline, not zero findings (`docs/development/linting.md`).

## Consequences

On GNOME Shell 51.1 the extension reaches state 1 `ACTIVE` with an empty error
and a generated stylesheet, using the committed `metadata.json`. Upstream's
`main` reaches `ERROR` on every Shell version, and with the declaration
unwidened it is refused as `OUT_OF_DATE`.

The fork diverges from upstream until the pull requests land, and carries the
port forward at each Shell release. The harness makes that cheap: widen the
declaration and it says whether anything else broke.

Reading Shell sources misled this work twice. The first two descriptions of the
message list, both derived from source, were wrong; the real shape (notifications
grouped per source, the `message` actors two levels below a
`NotificationMessageGroup`) came from querying the live actor tree through
`org.gnome.Shell.Eval`. Compatibility by inspection would have missed the three
silent defects too. The live tree, not the source, is the authority.

What inspection did establish, and the harness confirmed: no GI symbol, Shell
module export, private member, theme class name or GSettings key the extension
uses changed between 49 and 51.

The linter baseline (2729 findings) was produced under ESLint 10, which enables
one rule, `no-useless-assignment` (10 findings), that upstream's declared
dependency ranges do not (`tools/eslint-config-gnome/VENDORED.md`). Vendoring
means resyncing by hand when the Shell's pin moves.

The design and its review rounds are in
`docs/superpowers/specs/2026-10-22-gnome-51-port-design.md`.
