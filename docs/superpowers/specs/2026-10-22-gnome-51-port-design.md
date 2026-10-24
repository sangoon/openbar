# Design: port Open Bar to GNOME Shell 50 and 51

Date: 2026-10-22
Status: accepted
Scope: `openbar@neuromorph`, fork `sangoon/openbar`

## Context

### Goal

Make Open Bar load and work on GNOME Shell 51, keeping the fork maintainable
across future Shell releases, and offer the work back upstream.

### Target platform

Verified on the maintainer's workstation (CachyOS, Wayland):

| Component | Version |
|---|---|
| GNOME Shell | 51.1 |
| Mutter | 51.1 |
| GJS | 1.90.1 |
| GTK | 4.24.1 |
| libadwaita | 1.10 |

### Starting state

`main` is `01fb242` (2025-10-05), identical to upstream `neuromorph/openbar`.
Upstream has published nothing since; extensions.gnome.org advertises shell
versions 42 through 49 only. No GNOME 50 or 51 support exists anywhere.

`metadata.json` on `main` declares `version: 42` and
`shell-version: ["45","46","47","48","49"]`.

The copy installed at `~/.local/share/gnome-shell/extensions/openbar@neuromorph`
is **version 49**, obtained from extensions.gnome.org. It is therefore *newer*
than `main`. The only code difference between the two is four lines in
`extension.js`, described under "Defect 1" below: upstream shipped that fix on
extensions.gnome.org and never pushed it to git.

The repository has no `docs/`, no `CLAUDE.md`, no linter, no CI and no tests.

### Licence

Every source file carries `SPDX-License-Identifier: GPL-2.0-or-later`;
`LICENSE` holds the GPLv3 text. Forking, modifying and redistributing are
permitted provided the licence and the existing copyright notices are kept and
modifications are stated. Nothing else constrains this work.

## Decisions to confirm

| Decision | Chosen | Alternative considered |
|---|---|---|
| Defect 3 fix shape | Resolve the actors to theme **by style class**: collect every descendant of the message list carrying `message`, stop descending at the first match. One expression for 45 through 51, independent of how deeply the Shell nests them | A `gnomeVersion >= 49` branch, or resolving by tree position — both were tried on paper and both were wrong, see review log rounds 4 and 5 |
| Group chrome CSS | Out of scope. The four classes GNOME 49+ added for notification groups get no rules in this ticket; the gap is documented and ticketed separately | Extend `stylesheets.js` here, mixing theming design into a port offered upstream |
| DateMenu traversal | Keep upstream's index walking, wrap it in `try/catch` | Rewrite it to search by `style_class`; removes the defect class rather than the instance, but rewrites working code and is hard to land upstream |
| Lint reach | `npm run lint` over `openbar@neuromorph` plus the JavaScript this fork wrote itself (`eslint.config.js`, `tools/harness/`), with the per-file counts recorded in `docs/development/linting.md` as a baseline and a "no new findings" rule. Upstream's code carries a baseline; our own is held at zero. The vendored configuration under `tools/eslint-config-gnome/` is excluded, since linting a byte-identical copy measures someone else's repository | Lint only touched files: greener, but does not describe the real state. Or lint literally everything, which would report findings against vendored upstream code nobody here may change |
| Linter provenance | Vendor `eslint-config-gnome` under `tools/eslint-config-gnome/` at the commit gnome-shell 51.1 pins, with a `VENDORED.md` recording provenance and resync | Declare it as a git dependency on gitlab.gnome.org, which is how gnome-shell itself consumes it — refused by npm 12, see review log round 7 |
| Worktree location | `.claude/worktrees/<branch>`, added to `.gitignore` | A path outside the repository |
| Upstream contribution | Two separate pull requests to `neuromorph/openbar`: the v49 fix first, GNOME 51 support second | One all-or-nothing pull request |
| Branch | `feat/main/gnome-51-support` | — |

## Compatibility assessment

Every point of contact between the extension and the Shell was checked against
the GNOME Shell 51.1 sources, and diffed against 49.0 to separate real
regressions from pre-existing breakage.

### What still holds

- **Imports.** All seven `gi://` imports and all six
  `resource:///org/gnome/shell/` imports resolve. The exports the extension
  relies on are unchanged: `PanelMenu.Button`, `PanelMenu.ButtonBox`,
  `Calendar.Calendar`, `LayoutManager.LayoutManager`, `Config.PACKAGE_VERSION`.
  `main.js` and `layout.js` only gained exports between 49.0 and 51.1.
- **GI symbols.** The 48 distinct `St.*`, `Clutter.*`, `Meta.*`, `Gtk.*`,
  `Adw.*`, `Gdk*` and `Pango.*` symbols the sources reference all resolve
  against the installed typelibs.
- **Shell internals.** Every private member the extension reaches into is still
  present in 51.1: `Panel._leftBox` / `_centerBox` / `_rightBox`
  (`panel.js:474-479`), `MessageTray._bannerBin` and `_banner`
  (`messageTray.js:745,762`), `LayoutManager._bgManagers` (`layout.js:323`),
  `DateMenuButton._calendar`, `QuickSettingsMenu._boxPointer` and `_grid`, and
  `Calendar.prototype._rebuildCalendar` (`calendar.js:629`), which the extension
  monkey-patches.
- **Theme class names.** Diffing the selector set of `data/theme` between 49.0
  and 51.1 shows one removal, `.login-dialog-auth-list-label`, which the
  extension does not use. There is no theming regression from 49 to 51.
- **External GSettings.** All eight keys read or written
  (`org.gnome.desktop.interface` `color-scheme`, `accent-color`, `gtk-theme`,
  `icon-theme`; `org.gnome.desktop.background` `picture-uri`,
  `picture-uri-dark`; `org.gnome.desktop.a11y.interface` `high-contrast`;
  `org.gnome.shell` `enabled-extensions`) exist.
- **Own schema.** `glib-compile-schemas --strict` accepts
  `schemas/org.gnome.shell.extensions.openbar.gschema.xml`.
- **Version gating.** Existing gates are all `>=` or `<` comparisons
  (`gnomeVersion >= 47`, `< 48`, `< 49`), so 50 and 51 fall into the newest
  branch with no new code.

The only change required to make the extension load is the `shell-version`
array.

### Defects to fix

Each of these predates GNOME 51; all three affect it.

**Defect 1 — `clearBtn` is block-scoped and read out of scope.**
In `extension.js` on `main`, `clearBtn` is declared `const` inside both arms of
an `if`/`else` and read after both arms close. `applyMenuStyles` is called from
`enable()` with no `try/catch`, and the DateMenu branch runs unconditionally
because the date menu is always in the centre box. `main` therefore throws a
`ReferenceError` during `enable()` and the extension fails to activate on
*every* Shell version, not only 51. The v49 payload on extensions.gnome.org
fixes it by hoisting `let clearBtn;` above the `if`.

**Defect 2 — wrong child index for the Clear button.**
For `gnomeVersion >= 49` the code reads `msgHbox.get_child_at_index(1)`. In
`calendar.js` of both 49.0 and 51.1, the `message-list-controls` box receives
exactly one child, `_clearButton`, at index 0. The call returns `null`;
`applyMenuClass` filters null, so nothing throws, but the Clear button is never
themed.

**Defect 3 — the section level disappeared.**
`applySectionStyles` assumes the pre-49 structure where the message list held
`NotificationSection` and `MediaSection` objects, each exposing a `_list` whose
children are bins wrapping a message:

```
up to 48:  sectionList -> section -> section._list -> St.Bin -> .child = Message

since 49:  MessageView                         message-view
             +- St.Bin
                  +- NotificationMessageGroup  message-notification-group
                       +- <container>
                       |    +- NotificationMessage   message
                       +- St.BoxLayout         message-group-header
                            +- St.Label        message-group-title
                            +- St.Button       message-collapse-button
```

The 49+ shape above was read off a live Shell 51.1 through `Eval`, not inferred
from the sources. Two earlier readings of this area were wrong; see the review
log, rounds 4 and 5.

Notifications are now grouped per source. The actors carrying the `message`
style class sit two levels below the group, and the group itself carries
`message-notification-group`.

This matters because of how the generated stylesheet is written. Every rule is
`.openmenu.message`, a compound selector (`stylesheets.js:2463` and following),
so `openmenu` has to land **on the same actor** that carries `message`. Putting
it on the group matches nothing — while any probe would still report a class and
read as a pass.

The fix therefore resolves message actors **by style class rather than by tree
position**: collect, from the message list, every descendant carrying `message`,
and stop descending once one is found. That covers 45 through 51 in one
expression, with no version gate and no dependency on how deeply the Shell
nests them next.

`MessageView` also holds a non-message `_overlay` child, a `Clutter.Actor`,
which has no `has_style_class_name` method; the collector must guard for that
rather than assume every actor is an `St.Widget`.

The existing optional chaining keeps the current code from throwing, so the
failure is silent: notifications never receive the `openmenu` class.

### Out of scope, and why it is recorded here

GNOME 49+ also introduced `message-notification-group`, `message-group-header`,
`message-group-title` and `message-collapse-button`. None of the four appears
anywhere in `stylesheets.js`. So once `openmenu` reaches the `message` actors,
the notifications themselves theme correctly but the group's header and collapse
button stay unthemed.

Writing rules for them is theming design in a 3878-line generated stylesheet,
with no reference to match against — a different kind of work from a
compatibility port, and not something to fold into a pull request offered
upstream as a port. It is recorded in `docs/development/message-list-structure.md`
and carried as its own ticket.

### Known debt left out of scope

`prefs.js` uses six widgets deprecated since GTK 4.10: `Gtk.ColorButton`,
`Gtk.ComboBoxText`, `Gtk.FontButton`, `Gtk.FileChooserDialog`,
`Gtk.MessageDialog` and `Gtk.StyleContext`. All six are still present in GTK
4.24.1, so preferences work, with console warnings. Replacing them is an
interface rewrite over roughly 3000 lines and does not belong in a
compatibility port. It will break at GTK 5.

`stylesheets.js` (3878 lines), `prefs.js` (3024 lines) and `extension.js` (1664
lines) all exceed the thousand-line guideline, and the sources are heavily
commented. Per the opportunistic-migration rule, only code this port touches is
brought into line; the rest stays as upstream wrote it and is recorded as
pending migration in the local `CLAUDE.md`.

## Implementation

### Commit 1 — restore the fix upstream shipped but never pushed

`fix: restore clearBtn scope fix shipped in v49`

Import the v49 payload from extensions.gnome.org. The effective diff is the
hoisting of `let clearBtn;` above the `if`/`else`. Kept as its own commit so it
can be offered upstream, accepted, or reverted independently of the port.

### Commit 2 — GNOME 50 and 51 support

`feat: support GNOME 50 and 51`

- `metadata.json`: `shell-version` becomes
  `["45","46","47","48","49","50","51"]`; `version` becomes 50.
- Defect 2: the Clear button index becomes 0.
- Defect 3: `applySectionStyles` resolves what to theme **by style class**.
  `messageActors()` collects every descendant of the message list carrying
  `message`, stopping at the first match on each branch; `messageContainers()`
  returns the actors on the way down, which `trackMessageAdditions()` connects to
  so a notification arriving later is themed too. One shape covers 45 through 51
  with no version gate. See "Defect 3" above for why resolving by tree position
  cannot work here.
- The `DateMenuButton` traversal is wrapped in `try/catch` that logs and
  continues. Today any drift in Shell structure inside that block aborts
  `enable()` and puts the extension in `ERROR`; afterwards it degrades the date
  menu's theming and leaves the rest working. This is the general lesson of
  Defect 1, and it is the one piece of the structure-agnostic approach worth
  taking without rewriting the traversal.

### Function extraction

The DateMenu block becomes named methods, each doing one thing — `themeDateMenu`,
`themeMessagePane`, `themeMessageControls`, `themeCalendarPane` and
`scheduleCalendarGridStyle` — with the comments they replace moved into
`docs/development/message-list-structure.md`. This is the code this port touches,
so the six rules apply to it.

`themeCalendarPane` uses the existing `applyBoxStyles` in place of the three
hand-rolled nested `forEach` levels the inline block used.

## Verification

### Harness

A headless Shell, not a nested window:
`dbus-run-session -- gnome-shell --headless --virtual-monitor 1920x1080`.
Both options exist on the installed binary. The session is isolated from the
maintainer's own, leaves no window on screen, and can run unattended.

The extension is installed into a throwaway `XDG_DATA_HOME`, enabled, and three
things are asserted:

1. The extension reaches state `ACTIVE` with an empty `error` field.
2. The Shell's output contains no `JS ERROR` naming the extension.
3. `stylesheet.css` is generated under
   `$XDG_RUNTIME_DIR/io.github.neuromorph.openbar/`, and the output carries none
   of the `Openbar: Error loading stylesheet` lines the extension logs when
   `St.Theme.load_stylesheet` throws. `St.Theme` exposes no way to read back
   which sheets are loaded, so the absence of that log line is the available
   evidence, not proof the sheet took effect.

All three are exit-code assertions. Only the first was enforced until the
whole-branch review: the other two were printed for a human to read, so a throw
inside a signal handler or a timeout callback — which GJS logs and swallows
without changing extension state — passed silently. The harness also asserts
that an `--eval` probe was actually evaluated, and, with `--eval-contains`, that
its result holds an expected string; `org.gnome.Shell.Eval` answers
`(false, '')` when it refuses and `(false, '<error>')` when the expression
throws, and both used to exit 0.

Two properties of the harness are load-bearing, and both were found by watching
the harness report success while measuring nothing:

- **`GSETTINGS_BACKEND=keyfile` is mandatory.** Under `dbus-run-session` there
  is no activatable dconf service, so `gsettings set` fails silently:
  `enabled-extensions` reads back as `@as []`, the extension is never enabled,
  it sits at state `INITIALIZED`, and every assertion above passes vacuously.
  The keyfile backend writes
  `$XDG_CONFIG_HOME/glib-2.0/settings/keyfile` and needs no daemon.
- **State must be read from the Shell itself**, via
  `org.gnome.Shell.Extensions.GetExtensionInfo` on `/org/gnome/Shell`. The
  `gnome-extensions` CLI can be answered by a standalone, D-Bus-activated
  `org.gnome.Shell.Extensions` service that scans the disk, so it reports
  plausible states while the Shell is dead.

States are read as the numbers of `ExtensionState`
(`misc/extensionUtils.js:15-28`): 1 `ACTIVE`, 2 `INACTIVE`, 3 `ERROR`,
4 `OUT_OF_DATE`, 6 `INITIALIZED`.

### Measured result

The harness was run on GNOME Shell 51.1 against three payloads before this plan
was written:

| Payload | `state` | `error` |
|---|---|---|
| `main` code, `shell-version` `45-49` | 4 `OUT_OF_DATE` | — (never loaded) |
| `main` code, `shell-version` `45-51` | 3 `ERROR` | `ReferenceError: clearBtn is not defined` |
| v49 code, `shell-version` `45-51` | 1 `ACTIVE` | `''` |

The second row carries the stack trace
`applyMenuStyles@extension.js:396` called from `enable@extension.js:1535`,
confirming Defect 1 empirically. The third row establishes that Open Bar runs
on GNOME Shell 51.1 once the metadata is widened and that fix is in place, and
that `stylesheet.css` is generated.

### Positive controls

A check that has never been observed to fail proves nothing, so each assertion
ships with the mutation that breaks it:

- **`shell-version`**: the array left at `45-49` must yield state 4
  `OUT_OF_DATE`. Observed; see "Measured result" above.
- **Defect 1**: `main`'s code with the widened array must yield state 3 `ERROR`
  carrying `clearBtn is not defined`. Observed.
- **`INITIALIZED` is a harness failure, not a result.** State 6 means the
  extension was never enabled, so nothing downstream was measured. The harness
  treats it as an error of its own rather than a failed assertion, because the
  distinction is what the keyfile-backend bug cost.
- **`try/catch`**: a probe that forces a bad index inside the DateMenu
  traversal must produce a logged error *and* leave the extension state 1
  `ACTIVE`. Without the `try/catch` the same probe must leave it state 3
  `ERROR`. This proves the guard does something.
- **Defect 3**: a headless session has no notifications, so a probe that finds
  no message actor would pass vacuously. The probe therefore raises a
  notification first, asserts that at least one actor carrying the `message`
  class exists, and only then asserts `openmenu` on that same actor. It must
  fail against `main` and pass after the fix.

  Two further traps, both found by running the probe rather than reasoning about
  it. `Main.notify()` builds a notification with `isTransient: true`, which is
  not a reliable way to put something in the list; the probe constructs a
  non-transient `MessageTray.Notification` through a dynamic
  `import('resource:///org/gnome/shell/ui/messageTray.js')` inside the evaluated
  expression, which works because `Eval` awaits its result. And asserting
  `openmenu` on *any* actor is not enough: it must be asserted on the actor that
  also carries `message`, or the compound selector is not what was tested.

- **The probe itself**: `--eval-contains openmenu` over that probe must exit 0,
  and must exit non-zero once `trackMessageAdditions` is mutated out, which
  leaves `classes` reading `["message"]`. Until the review this control passed
  either way, because the probe's result was printed rather than asserted.

- **The calendar pane**: a probe walking the pane children, their children and
  their grandchildren — the reach of `applyBoxStyles` — must find no actor
  without `openmenu`, and must find 19 of them once the `applyBoxStyles` call is
  mutated out. This is the only assertion covering the refactor that replaced
  three nested `forEach` levels with `applyBoxStyles`.

The verification procedure is written to `docs/development/testing.md` so it is
reproducible without this document.

## Deliverables

- `openbar@neuromorph/metadata.json`, `openbar@neuromorph/extension.js`
- `docs/adr/0001-port-to-gnome-51.md` — the decision, upstream's state, and how
  compatibility was established
- `docs/development/testing.md` — the headless verification procedure
- `docs/development/linting.md` — how to run the linter and the baseline count
- `CLAUDE.md` — licence constraint, upstream code pending migration, how to test
- `eslint.config.js`, `package.json` with `npm run lint`, using
  `eslint-config-gnome` vendored under `tools/eslint-config-gnome/` at the
  commit gnome-shell 51.1 pins. It is not published on npm, and npm 12 refuses
  git dependencies and remote tarballs by default, so depending on it directly
  — as gnome-shell does — would mean relaxing that default for everyone who
  clones. `tools/eslint-config-gnome/VENDORED.md` records provenance and resync
- `.gitignore` gains `.claude/`
- Two pull requests proposed to `neuromorph/openbar`

## Review log

Sorted by round, ascending; the dates rise with it, and a round's number is
the order it happened in.

| Date | Round | Trigger | Outcome |
|---|---|---|---|
| 2026-10-22 | 1 | Initial brainstorming: clone, licence check, compatibility assessment | Scope set to the port alone; fork maintained with upstream pull requests offered; approach A (resync commit then port commit) with the `try/catch` borrowed from approach C; tooling bootstrap limited to docs, local `CLAUDE.md` and a linter |
| 2026-10-22 | 2 | Self-review before handing the spec over | Two over-claims corrected: `St.Theme` exposes no way to read back loaded sheets, so assertion 3 rests on the absence of the extension's own error log; and the Defect 3 probe would pass vacuously in a headless session with no notifications, so it now raises one and asserts a message actor exists first |
| 2026-10-22 | 3 | Spec reviewed in Plannotator | All six decisions in "Decisions to confirm" accepted as proposed, no changes requested. Table kept as the record of what was weighed |
| 2026-10-22 | 4 | Harness prototyped before writing the plan, to avoid prescribing an unverified test | Three corrections. The accepted Defect 3 fix `section._list ?? section` was **wrong**: reading `MessageView._addMessageAtIndex` showed the section level disappeared, not `_list`, so that expression reached one level too deep and would have themed grandchildren. Fix moved to the container level. The harness gained two mandatory properties found by watching it report success while measuring nothing: `GSETTINGS_BACKEND=keyfile`, without which the extension never enables, and reading state from the Shell rather than the `gnome-extensions` CLI. Compatibility is now established empirically, not only by inspection: the port reaches state `ACTIVE` on 51.1 |
| 2026-10-23 | 5 | Probed the live Shell 51.1 actor tree before dispatching the Defect 3 fix | The round 4 correction was **also wrong**, and in the same direction: it moved the target up one level inside a deeper mistake. The real shape has two levels round 4 did not know about — notifications are grouped, and the actors carrying `message` sit two levels below `NotificationMessageGroup`. The container-level fix accepted in round 3 would have put `openmenu` on the group, which matches none of the `.openmenu.message` compound rules, while still showing a class to any probe: a passing test over dead theming. Fix re-specified to resolve by style class instead of by tree position. Separately, the four group classes GNOME 49+ added have no rules in `stylesheets.js` at all; the owner ruled that out of scope for this ticket, documented and ticketed on its own. Lesson recorded plainly: this area was described from source reading three times and got it wrong twice; the live tree is the only authority |
| 2026-10-23 | 6 | Task 8 flagged that the Implementation section still described the superseded fix | Two stale claims the round 5 correction missed, both introduced by the controller and both found by an implementer rather than by review: Defect 3 was still written as `section._list ?? section`, and the extracted functions were named `themeMessageList`/`themeClearButton`, which match no method in the tree. Corrected to the by-style-class resolution and to the real method names. The lesson is narrower than round 5 and worth keeping: correcting a decision in one section of a document does not correct the sections that restate it |
| 2026-10-23 | 7 | Task 7 attempted; `npm install` refused the git dependency this document specified | The linter configuration is vendored instead. npm 12 refuses git dependencies (`EALLOWGIT`) and remote tarballs (`EALLOWREMOTE`) by default, and `eslint-config-gnome` is not published on npm, so the specified dependency could not be installed without relaxing an npm security default for everyone who clones the repository. The owner chose vendoring the exact commit gnome-shell 51.1 pins, with a `VENDORED.md` recording provenance, licence and how to resync. The plan was revised the same day; this document was not, so its Deliverables still named a git dependency and its Decisions table still recorded a lint reach of "the whole repository" that `package.json` never had, with no row for the vendoring decision at all. All three corrected here, three commits late; the table now holds eight rows where round 3 accepted six. This is round 6's lesson again, one document further out: correcting a decision where it was taken does not correct the documents that restate it |
