# hyprmoncfg Workspaces

See where your workspaces are. Plain numbers are grouped by screen in the bar:
`1 2 3   4 5 6`. They use Omarchy's normal size and spacing, with a small gap
between monitors. Click any number to focus it on its actual screen.

With hyprmoncfg's **Per display** workspace strategy, the bar looks and works
like Omarchy's own workspace widget, fed by hyprmoncfg. Each screen's bar shows
only that screen's workspaces, numbered `1 2 3` with slot ten as `0`: the first
five slots (fewer if the screen has fewer), any others in use, then, after a
gap, workspaces visiting from an unplugged screen. Each bar highlights the
workspace its screen shows, with the underline or, with `accentFocused`, the
accent colour. Clicking a slot switches to it the way Omarchy does, and
scrolling, up and down or sideways, moves along the screen's own row. hyprmoncfg says which block of ten
each screen owns, so this also works on Omarchy before 4.5, where hyprmoncfg
runs per display workspaces itself. Right-click still opens the workspace
planner.

In the grouped view the focused workspace has a small underline, or, with
`"accentFocused": true` in the widget's `shell.json` entry, its number in the
theme's accent colour and bold. Visible and occupied workspaces are bright, and empty
workspaces are dimmed. Scroll within a group to switch
that screen's workspaces. Right-click a number to open just the **Workspaces**
tab in a popup beside the picker: strategy, group size, monitor order, assignments,
and the same Apply/Save and confirmation controls as the hyprmoncfg panel. It
shares the existing editor and preview guard. It has no Layout or Profiles tabs.
Choose **hyprmoncfg**, beside Identify all, to open the full display editor on
Layout from the display panel's own bar icon, without losing workspace edits or an active preview.
The workspace-plan numbers also switch workspaces, including numbers omitted from
the compact bar. Finish drafts or previews before switching from the planner.
The separate monitor panel keeps Omarchy's original icon size with an accent check.

## Install

```sh
omarchy plugin install https://github.com/crmne/omarchy-hyprmoncfg-workspaces
```

This replaces the stock workspace widget through Omarchy's normal plugin
mechanism. The original remains installed. Keep one workspace widget enabled:

- **hyprmoncfg Workspaces** for grouped numbers (Omarchy's per screen bar with
  the Per display strategy) and the workspace planner popup.
- [**Global Workspaces**](https://github.com/crmne/omarchy-global-workspaces) for
  the classic global-number picker.
- **Omarchy Workspaces** for Omarchy's monitor-local workspace management.

These are presentation choices. The plugin does not change your monitor layout,
workspace assignments, ownership, shortcuts, or saved profiles. Global widgets
should be paired with global shortcuts, such as hyprmoncfg's enabled workspace
planner on a compatible build. With the **Per display** strategy, this widget
stands in for Omarchy's own: it numbers each screen 1-10 like Omarchy's
shortcuts do and adds the planner popup. To use Omarchy's management instead, explicitly
choose Off in hyprmoncfg's workspace planner and use the stock widget.

## Requirements and data

Requires Omarchy's Quickshell shell with plugin support and Hyprland. hyprmoncfg
1.26.0 or newer supplies `workspace_plan` in its status stream to
include assigned empty workspaces, and a hyprmoncfg build with the per display
strategy adds `per_display_workspaces` (block size, slots per screen, each
screen's block, and whether Omarchy runs the workspaces) for the per screen
bar. Without it, numbers stay global and grouped. Older or stopped daemons still allow switching
existing workspaces. The planner popup requires the separately installed
[hyprmoncfg panel](https://github.com/crmne/omarchy-hyprmoncfg), version 2.11.0 or newer. Until it is available, the live spatial overview stays
usable. Setup has two stages:

1. **Install hyprmoncfg panel**, **Enable hyprmoncfg panel**, or **Update hyprmoncfg
   panel**, according to what is missing. Omarchy's normal interactive installer
   keeps its trust, enablement and placement questions. Enabling the panel opens
   the next step automatically.
2. The panel's existing **Install hyprmoncfg** or **Update hyprmoncfg** screen adds
   the daemon when needed, with the same progress, error handling and presented
   terminal as the display panel. A stopped daemon gets its normal service controls.

Once ready, the picker shows the Workspaces planner and the **hyprmoncfg** shortcut
opens the full display panel. The picker never maintains a second package installer.

One read-only subscription to `$XDG_RUNTIME_DIR/hyprmoncfgd.sock` supplies the
plan. Quickshell supplies live compositor state. Existing workspace locations
take precedence over assignments, so unplugging a screen does not leave false
locations in the bar. Switching is a direct Hyprland IPC dispatch and never
calls a daemon switching command or launches a shell process. No background network calls,
clipboard access or periodic workspace polling. Installing the optional panel
uses Omarchy's installer only after you choose a panel setup action. The Ruby helper
uses local plugin discovery and waits briefly for the reloaded panel to open.
Configuration changes go through
the panel's existing editor and its explicit Apply/Save confirmation. Connection
retries run only while the daemon is unavailable.

The widget currently presents positive numeric workspaces. Special and named
workspaces remain accessible through your normal Hyprland controls. Geometry is
live; changing display positions only changes the drawing, never workspace IDs.

## Remove

```sh
omarchy plugin remove crmne.hyprmoncfg-workspaces
```

Re-enable your preferred workspace widget through Omarchy's bar settings.

## Development

```sh
node --test tests/*.test.js
/usr/lib/qt6/bin/qmllint --max-warnings -1 *.qml
omarchy plugin validate .
ruby tests/runtime.rb
ruby tests/reconnect.rb
ruby tests/limits.rb
ruby tests/setup-panel.rb
```

The runtime test uses real Qt/Omarchy components in a Hyprland session with
workspace dispatches captured. It never injects keyboard or mouse input or
changes the monitor configuration. The model tests cover three-screen and
stacked arrangements, rotation, scaling, mirrors, unplugging, connector reuse,
stopped/older daemons, global IDs above ten, and per display mode: block
resolution, the numbers each screen shows, slot labels, delegated and direct
switching, and scrolling. The runtime test also drives per display mode
through the real delegates, including the highlight of the shown workspace. The reconnect test runs the
production service against an isolated local socket, checks ten peer closures
and re-subscriptions, and never contacts your running daemon. The limits test
does the same with a misbehaving fake daemon: a line that never ends is cut
off at 4 MiB, a reply with an invalid status leaves the response watchdog
running until it reconnects, and a character split between two reads is
repaired with a fresh snapshot. It also checks that a probe printing more than
its limit is stopped at once. The setup helper's tests check the same limit on
`omarchy plugin list`.

MIT licensed. Uses Omarchy's standard UI components and theme.
