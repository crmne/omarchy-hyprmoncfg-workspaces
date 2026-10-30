# hyprmoncfg Workspaces

See where your workspaces are. Plain numbers are grouped by screen in the bar:
`1 2 3   4 5 6`. They use Omarchy's normal size and spacing, with a small gap
between monitors. Click any number to focus it on its actual screen.

The focused workspace has a small underline. Visible and occupied workspaces
are bright, and empty workspaces are dimmed. Scroll within a group to switch
that screen's workspaces. Right-click a number to open just the **Workspaces**
tab in a popup beside the picker: strategy, group size, monitor order, assignments,
and the same Apply/Save and confirmation controls as the hyprmoncfg panel. It
shares the existing editor and preview guard. It has no Layout or Profiles tabs.
Choose **hyprmoncfg**, beside Identify all, to open the full display editor on
Layout without losing workspace edits or an active preview.
The workspace-plan numbers also switch workspaces, including numbers omitted from
the compact bar. Finish drafts or previews before switching from the planner.
The separate monitor panel keeps Omarchy's original icon size with an accent check.

## Install

```sh
omarchy plugin install https://github.com/crmne/omarchy-hyprmoncfg-workspaces
```

This replaces the stock workspace widget through Omarchy's normal plugin
mechanism. The original remains installed. Keep one workspace widget enabled:

- **hyprmoncfg Workspaces** for grouped numbers and the workspace planner popup.
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
existing workspaces. The planner popup requires the separately installed
[hyprmoncfg panel](https://github.com/crmne/omarchy-hyprmoncfg), with the UI route
added on main after 2.10.1. Until it is available, the live spatial overview stays
usable. It offers **Install hyprmoncfg** when the panel is missing or disabled, using
Omarchy's normal interactive installer. An older panel can still be opened through
the **hyprmoncfg** button.

One read-only subscription to `$XDG_RUNTIME_DIR/hyprmoncfgd.sock` supplies the
plan. Quickshell supplies live compositor state. Existing workspace locations
take precedence over assignments, so unplugging a screen does not leave false
locations in the bar. Switching is a direct Hyprland IPC dispatch and never
calls a daemon switching command or launches a shell process. No background network calls,
clipboard access or periodic workspace polling. Installing the optional panel
uses Omarchy's installer only after you choose Install hyprmoncfg. Configuration changes go through
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
```

The runtime test uses real Qt/Omarchy components in a Hyprland session with
workspace dispatches captured. It never injects keyboard or mouse input or
changes the monitor configuration. The model tests cover three-screen and
stacked arrangements, rotation, scaling, mirrors, unplugging, connector reuse,
stopped/older daemons, and global IDs above ten. The reconnect test runs the
production service against an isolated local socket, checks ten peer closures
and re-subscriptions, and never contacts your running daemon.

MIT licensed. Uses Omarchy's standard UI components and theme.
