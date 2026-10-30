# hyprmoncfg Workspaces

See where your workspaces are. Plain numbers are grouped by screen in the bar:
`1 2 3   4 5 6`. They use Omarchy's normal size and spacing, with a small gap
between monitors. Click any number to focus it on its actual screen.

The focused workspace has a small underline. Visible and occupied workspaces
are bright, and empty workspaces are dimmed. Scroll within a group to switch
that screen's workspaces. Right-click a number for an overview arranged like
your monitors, including stacked and portrait displays. Extra numbers are
available through the overview; the bar initially shows up to five per screen.
The separate hyprmoncfg panel keeps its original icon.

## Install

```sh
omarchy plugin install https://github.com/crmne/omarchy-hyprmoncfg-workspaces
```

This replaces the stock workspace widget through Omarchy's normal plugin
mechanism. The original remains installed. Keep one workspace widget enabled:

- **hyprmoncfg Workspaces** for grouped numbers and the spatial overview.
- [**Global Workspaces**](https://github.com/crmne/omarchy-global-workspaces) for
  the classic global-number picker.
- **Omarchy Workspaces** for Omarchy's monitor-local workspace management.

These are presentation choices. The plugin does not change your monitor layout,
workspace assignments, ownership, shortcuts, or saved profiles. Global widgets
should be paired with global shortcuts, such as hyprmoncfg's enabled workspace
planner on a compatible build. To use Omarchy's management instead, explicitly
choose Off in hyprmoncfg's workspace planner and use the stock widget.

## Requirements and data

Requires Omarchy's Quickshell shell with plugin support and Hyprland. A hyprmoncfg
development build after 1.25.1 supplies `workspace_plan` in its status stream to
include assigned empty workspaces. Older or stopped daemons still allow switching
existing workspaces. Configure displays opens the separately installed
[hyprmoncfg panel](https://github.com/crmne/omarchy-hyprmoncfg).

One read-only subscription to `$XDG_RUNTIME_DIR/hyprmoncfgd.sock` supplies the
plan. Quickshell supplies live compositor state. Existing workspace locations
take precedence over assignments, so unplugging a screen does not leave false
locations in the bar. Switching is a direct Hyprland IPC dispatch and never
calls a daemon switching command or launches a shell process. No network calls,
clipboard access, profile writes, or periodic workspace polling. Connection
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
```

The runtime test uses real Qt/Omarchy components in a Hyprland session with
workspace dispatches captured. It never injects keyboard or mouse input or
changes the monitor configuration. The model tests cover three-screen and
stacked arrangements, rotation, scaling, mirrors, unplugging, connector reuse,
stopped/older daemons, and global IDs above ten. The reconnect test runs the
production service against an isolated local socket, checks ten peer closures
and re-subscriptions, and never contacts your running daemon.

MIT licensed. Uses Omarchy's standard UI components and theme.
