# Verifying a change against a real Shell

`tools/verify-headless.sh` starts a throwaway GNOME Shell, installs this
extension into a scratch `XDG_DATA_HOME`, enables it, and reports the state the
Shell itself assigns it. It touches nothing in the session you are logged into
and opens no window.

    dbus-run-session -- ./tools/verify-headless.sh

Exit 0 means every assertion below held. The harness refuses to run when
`org.gnome.Shell` already has an owner on the session bus, so it cannot report
on a live session.

## What it asserts

All five are exit-code assertions, not lines to read:

1. State 1 `ACTIVE` with an empty `error` field. State 6 `INITIALIZED` fails
   with a message of its own: it means the extension was never enabled, so
   nothing downstream was measured.
2. `stylesheet.css` was generated under
   `$XDG_RUNTIME_DIR/io.github.neuromorph.openbar/`.
3. The extension logged no `Openbar: Error loading stylesheet` line.
   `St.Theme` exposes no way to read back which sheets are loaded, so the
   absence of that log line is the available evidence, not proof the sheet took
   effect.
4. No `JS ERROR` block in the Shell's output names `openbar@neuromorph`. This
   is the assertion that catches a throw inside a signal handler or a timeout
   callback: GJS logs those and swallows them, so the extension stays `ACTIVE`
   and the state assertion alone would pass.
5. With `--eval`, the probe was actually evaluated, and with
   `--eval-contains`, its result holds the expected string.

A *guarded* failure is deliberately not a `JS ERROR`: `themeDateMenu` catches,
logs `Openbar: Could not theme the date menu` through `console.error` and
continues. Assertion 4 therefore still passes under the guard mutation below,
which is what makes that mutation a control of the guard rather than of the
harness.

## Options

| Option | Effect |
|---|---|
| `--as-is` | Do not widen `shell-version` in the scratch copy of the extension. Used to assert that an unsupported declaration is refused. The harness helper's own declaration is widened either way. |
| `--mutate SED_EXPR` | Apply a `sed -i` expression to the scratch `extension.js` before launch. Used to inject a fault and confirm an assertion catches it. An expression that changes nothing fails the run. |
| `--eval JS` | Evaluate one expression inside the test Shell after the state check and print the result. |
| `--eval-contains STRING` | Fail the run unless the `--eval` result contains this literal string. Needs `--eval`. |

### Why `--eval` has two failure modes of its own

`org.gnome.Shell.Eval` answers `(true, '<json>')` only when it ran the
expression. Both other answers used to leave the harness exiting 0 with the
probe having measured nothing, so both now fail:

- `(false, '')` — Eval was refused. This almost always means the unsafe-mode
  helper did not load, not that the probe is wrong.
- `(false, '<something>')` — the probe expression itself threw, and
  `<something>` is the error.

`--eval-contains` is what turns the printed result into an exit code. A probe
without it is a line for a human to read, which is not a test.

## What it prints

After the state, the harness prints the `--eval` result if any,
`stylesheet: generated|absent`, the count of `Openbar: Error loading stylesheet`
lines, the count of lines naming the extension inside a `JS ERROR` block, a
12-line excerpt after each `JS ERROR` (capped at 40 lines, so it can include
unrelated Shell lines), and every log line containing `Openbar:` (capped at 20).
Everything is printed before anything is asserted, so a failing run still
carries its diagnosis.

## Why it is built this way

Two properties are load-bearing, and both were found by watching an earlier
version of this harness report success while measuring nothing.

`GSETTINGS_BACKEND=keyfile` is mandatory. Under `dbus-run-session` there is no
activatable dconf service, so `gsettings set` fails silently,
`enabled-extensions` reads back as `@as []`, the extension is never enabled, and
it sits at state 6 `INITIALIZED` while every downstream assertion passes
vacuously. The harness therefore treats state 6 as a failure of itself.

State is read from the Shell over
`org.gnome.Shell.Extensions.GetExtensionInfo` on `/org/gnome/Shell`, not from
the `gnome-extensions` CLI. That CLI can be answered by a standalone,
D-Bus-activated `org.gnome.Shell.Extensions` service which scans the disk, so it
reports plausible states while the Shell is dead.

## Inspecting the actor tree

`--eval` works because the harness also installs
`tools/harness/unsafemode@local`, a 12-line extension that sets
`global.context.unsafe_mode = true` so `org.gnome.Shell.Eval` answers.
`global.context.unsafe_mode` cannot be set from outside the Shell, and
`Eval` returns `(false, '')` without it.

The helper's `shell-version` is widened to the running Shell's major on every
run, `--as-is` included. A helper that goes `OUT_OF_DATE` at the next Shell
release would leave `unsafe_mode` unset, every probe answering `(false, '')`,
and — before that answer became a failure — every probe silently measuring
nothing.

`Main` is in scope for evaluated code, because `js/ui/shellDBus.js` imports it.

The helper is installed only into the scratch directory. It is never part of a
release.

## Regression checks

Each of these is a probe plus the mutation that makes it fail. A probe that has
never been seen to fail is not evidence.

### The message actors carry the compound class

Write the probe to a file, because the quoting is otherwise unmanageable:

```sh
cat > /tmp/openbar-probe.js <<'EXPR'
(async () => { const MT = await import('resource:///org/gnome/shell/ui/messageTray.js'); const GLib = (await import('gi://GLib')).default; const source = MT.getSystemSource(); source.addNotification(new MT.Notification({source, title: 'openbar-probe', body: 'probe body', isTransient: false})); await new Promise(resolve => GLib.timeout_add(0, 600, () => { resolve(); return false; })); const dateMenu = Main.panel.statusArea.dateMenu; const view = dateMenu.menu.box.get_child_at_index(0).get_child_at_index(0).get_child_at_index(0).get_child_at_index(1).get_child_at_index(0).child; const collect = actor => actor.has_style_class_name?.('message') ? [actor] : actor.get_children().flatMap(collect); const messages = view.get_children().flatMap(collect); return {count: messages.length, classes: messages.map(a => a.style_class)}; })()
EXPR
sh -c 'dbus-run-session -- ./tools/verify-headless.sh --as-is --eval "$(cat /tmp/openbar-probe.js)" --eval-contains openmenu'
```

The probe raises its own notification: a headless list can be empty, and a check
that finds no message actor passes without having looked at anything. Expected:
exit 0 and

    eval: (true, '{"count":1,"classes":["message openmenu"]}')

`count` is not stable across runs — the Shell sometimes raises a notification of
its own during startup — so judge "non-zero, and every entry carrying both
`message` and `openmenu`", never an exact number.

Its mutation, which must exit non-zero with `classes` reading `["message"]`:

```sh
sh -c 'dbus-run-session -- ./tools/verify-headless.sh --as-is --mutate "s/this.trackMessageAdditions(list, add);//" --eval "$(cat /tmp/openbar-probe.js)" --eval-contains openmenu'
```

### The calendar pane is themed to the same depth as before

`themeCalendarPane` replaced three hand-written nested `forEach` levels with
`applyBoxStyles`, which reaches each pane child, its children and its
grandchildren. This probe walks exactly that reach and counts what `openmenu`
did not land on:

```sh
cat > /tmp/openbar-calendar-probe.js <<'EXPR'
(() => { const panes = Main.panel.statusArea.dateMenu.menu.box.get_child_at_index(0).get_child_at_index(0); const reach = item => [item, ...item.get_children(), ...item.get_children().flatMap(child => child.get_children())]; const actors = panes.get_child_at_index(1).get_children().flatMap(reach).filter(actor => actor.has_style_class_name); const unthemed = actors.filter(actor => !actor.has_style_class_name('openmenu')); return {total: actors.length, unthemed: unthemed.length, unthemedClasses: unthemed.map(actor => actor.style_class)}; })()
EXPR
sh -c 'dbus-run-session -- ./tools/verify-headless.sh --as-is --eval "$(cat /tmp/openbar-calendar-probe.js)" --eval-contains "\"unthemed\":0"'
```

Expected: exit 0 and

    eval: (true, '{"total":69,"unthemed":0,"unthemedClasses":[]}')

`total` depends on what the calendar pane holds in a headless session; assert on
`unthemed` being 0, not on the total. The non-`St.Widget` actors are filtered
out because `applyMenuClass` skips anything without `add_style_class_name`.

Its mutation, which must exit non-zero with 19 unthemed actors — the pane's own
children and their descendants, leaving only what
`applyCalendarGridStyle` reaches:

```sh
sh -c 'dbus-run-session -- ./tools/verify-headless.sh --as-is --mutate "s/this.applyBoxStyles(item, add);//" --eval "$(cat /tmp/openbar-calendar-probe.js)" --eval-contains "\"unthemed\":0"'
```

### The date menu guard degrades instead of aborting

```sh
sh -c 'dbus-run-session -- ./tools/verify-headless.sh --as-is --mutate "s/const panes = calendarArea.get_child_at_index(0);/const panes = calendarArea.get_child_at_index(9);/"'
```

Expected: exit 0, state 1.0, `extension JS errors: 0`, and
`Openbar: Could not theme the date menu` in the log. Without the guard the same
mutation leaves the extension at state 3 `ERROR`.

## States

`ExtensionState`, from `js/misc/extensionUtils.js`:

| Number | Name |
|---|---|
| 1 | `ACTIVE` |
| 2 | `INACTIVE` |
| 3 | `ERROR` |
| 4 | `OUT_OF_DATE` |
| 6 | `INITIALIZED` |
