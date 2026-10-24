# Open Bar: fork conventions

## Licence

Every source file is GPL-2.0-or-later and carries an SPDX header plus
`author: neuromorph`. Keep both. Modifications must be stated. This is a fork,
not a rewrite.

## Upstream

`neuromorph/openbar` has been inactive since 2025-10-05. Changes here are
offered upstream as separate, individually defensible pull requests. See
`docs/adr/0001-port-to-gnome-51.md`.

The version published on extensions.gnome.org is newer than upstream's git
`main`. Compare against the released copy, not only against git, before assuming
a defect is yours.

## Verifying a change

Never claim a change works from reading alone. Run it:

    dbus-run-session -- ./tools/verify-headless.sh

State 1 `ACTIVE` with an empty error is a pass. State 6 `INITIALIZED` means the
harness measured nothing. `docs/development/testing.md` has the options and the
two traps the harness exists to avoid.

## The date menu has been misdescribed before

The message list's structure was described wrongly twice from reading GNOME
Shell's sources, once while correcting the first. What is true was read from the
live tree through `org.gnome.Shell.Eval` (`--eval` in the harness). Trust the
tree over the source, and see `docs/development/message-list-structure.md`.

Stylesheet rules are the compound selector `.openmenu.message`. A class on the
wrong actor matches nothing, and a probe that asks only whether some actor got a
class will still pass. Assert on an actor that carries `message`, after raising
a notification.

Known gap: GNOME 49+ group chrome (`message-notification-group`,
`message-group-header`, `message-group-title`, `message-collapse-button`) is not
themed. It is tracked as Vikunja ticket #2
(<https://tasks.sangoon.fr/tasks/177>); do not fold it into a compatibility
change.

## Code conventions

The maintainer's global rules apply to code this repository changes, not to the
whole tree. The upstream sources predate them: they are heavily commented, and
`stylesheets.js`, `prefs.js` and `extension.js` all exceed a thousand lines.
That is pending migration, not an invitation to rewrite the repository. Bring
what you touch into line; leave the rest.

    npm install
    npm run lint

The rule is no new findings, not zero findings. `docs/development/linting.md`
holds the baseline; update it when a change moves the count.
