# Verifying a change against a real Shell

`tools/verify-headless.sh` starts a throwaway GNOME Shell, installs this
extension into a scratch `XDG_DATA_HOME`, enables it, and reports the state the
Shell itself assigns it. It touches nothing in the session you are logged into
and opens no window.

    dbus-run-session -- ./tools/verify-headless.sh

Exit 0 means the Shell reached state 1 `ACTIVE` with an empty error. The harness refuses to run when `org.gnome.Shell` already has an owner on the session bus, so it cannot report on a live session.

## Options

| Option | Effect |
|---|---|
| `--as-is` | Do not widen `shell-version` in the scratch copy. Used to assert that an unsupported declaration is refused. |
| `--mutate SED_EXPR` | Apply a `sed -i` expression to the scratch `extension.js` before launch. Used to inject a fault and confirm a guard catches it. |
| `--eval JS` | Evaluate one expression inside the test Shell after the state check and print the result. |

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
`tools/harness/unsafemode@local`, a two-line extension that sets
`global.context.unsafe_mode = true` so `org.gnome.Shell.Eval` answers.
`global.context.unsafe_mode` cannot be set from outside the Shell, and
`Eval` returns `(false, '')` without it.

`Main` is in scope for evaluated code, because `js/ui/shellDBus.js` imports it.

The helper is installed only into the scratch directory. It is never part of a
release.

## States

`ExtensionState`, from `js/misc/extensionUtils.js`:

| Number | Name |
|---|---|
| 1 | `ACTIVE` |
| 2 | `INACTIVE` |
| 3 | `ERROR` |
| 4 | `OUT_OF_DATE` |
| 6 | `INITIALIZED` |
