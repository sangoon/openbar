# The date menu's message list, before and after GNOME 49

Open Bar puts its `openmenu` class on the actors it themes. The date menu's
message list changed shape in GNOME 49, and the change is deeper than it looks.

    up to 48:  sectionList -> section -> section._list -> St.Bin -> .child = Message

    since 49:  MessageView                         message-view
                 +- St.Bin
                      +- NotificationMessageGroup  message-notification-group
                           +- <container>
                           |    +- NotificationMessage   message
                           +- St.BoxLayout         message-group-header
                                +- St.Label        message-group-title
                                +- St.Button       message-collapse-button

Up to GNOME 48 the list held a `NotificationSection` and a `MediaSection`, each
exposing a `_list` whose children were bins wrapping one message.

Since GNOME 49 notifications are grouped per source. The sections are gone, and
so is the flat list of messages: the actors carrying the `message` class now sit
two levels below a `NotificationMessageGroup`.

## Why the class has to land on the `message` actor itself

Every rule in the generated stylesheet is written `.openmenu.message` — a
compound selector, both classes on one actor. Putting `openmenu` on the group
instead matches nothing, and the failure is invisible: a probe asking "did any
actor get a class?" answers yes.

`messageActors()` therefore resolves what to theme **by style class, not by tree
position**: it walks down from the list and collects every descendant carrying
`message`, stopping at the first match on each branch. One expression covers 45
through 51 and does not care how deeply a future Shell nests them.

`messageContainers()` is its complement — every actor on the way down, excluding
the messages. Those are the actors that can gain children, so those are the ones
`trackMessageAdditions()` connects to, which is how a notification arriving into
an already-open menu still gets themed.

`MessageView` also holds a non-message `_overlay` child, a plain
`Clutter.Actor`. `has_style_class_name` exists only on `St.Widget`, so the walk
calls it with `?.` rather than assuming every actor is one.

## How this was established

By reading the live actor tree through `org.gnome.Shell.Eval` in the test
harness, not by reading the Shell's sources. Two earlier descriptions of this
structure, both derived from source reading, were wrong — the second while
correcting the first. `docs/superpowers/specs/2026-10-22-gnome-51-port-design.md`
records both in its review log.

A probe for this behaviour must raise a notification first, and must assert on
an actor that carries `message`. A headless session can present an empty list,
and a check that finds no message actor passes without having looked at
anything.

## Known gap: the group's own chrome

GNOME 49+ introduced `message-notification-group`, `message-group-header`,
`message-group-title` and `message-collapse-button`. None of the four appears
anywhere in `stylesheets.js`.

So notifications theme correctly, and the header and collapse button of each
group do not. Writing rules for them is theming design in a 3878-line generated
stylesheet, which is a different kind of work from a compatibility port; it is
tracked as Vikunja ticket #2 (<https://tasks.sangoon.fr/tasks/177>) rather than
folded into this one.

## Why the traversal is guarded

`themeDateMenu()` wraps the walk in a `try`/`catch` that logs and continues.
The walk addresses children by index, so any change in the date menu's actor
hierarchy raises. `applyMenuStyles()` is called from `enable()` with no handler
of its own, so before the guard a single wrong index put the whole extension in
`ERROR` — which is exactly what the `clearBtn` defect did on every Shell
version.

The guard is verified by mutation, not by inspection: `verify-headless.sh
--mutate` forces a bad index and the extension must stay `ACTIVE` with the
failure logged. Without the guard the same mutation must produce `ERROR`.

One guard covers both panes, so a drift in the message pane also costs the
calendar pane its theming even though nothing about the calendar changed.
Splitting it into one guard per pane was considered and deferred to the next
time `themeDateMenu()` is touched: the finer granularity buys partial theming in
a case that has not yet occurred, and the port's own rule is to change only what
it must.

## Shape of the date menu, as the traversal reads it

The walk goes menu box, calendar area, then two panes: the message pane on the
left and the calendar pane on the right.

- Message pane: child 0 is the "No Notifications" placeholder, child 1 the box
  holding the scrolled section list and the controls row.
- Controls row: before GNOME 49 the Do Not Disturb button is child 1 (its
  toggle switch is its child 0) and the Clear button child 2; from 49 the Clear
  button is child 0.
- Calendar pane: every child is themed with `applyBoxStyles()`, which covers
  the child, its children and its grandchildren, as the former hand-written
  nested loops did. Only the `Calendar` child also gets its day grid styled,
  once immediately and once after 250 ms, because the grid is rebuilt after
  the menu opens.

The harness prints every `Openbar:` log line, so a guarded failure shows up as
`Openbar: Could not theme the date menu` followed by the error and its stack.
`testing.md` describes what the harness reports.
