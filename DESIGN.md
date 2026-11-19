# Workspace presentation

The bar stays as quiet and compact as Omarchy's own workspace widget. Use
plain global numbers, standard 20-pixel slots and 1-pixel spacing, plus the standard 6-pixel separator
between monitor groups. Scale these values through Omarchy's theme. No group backgrounds, borders, or extra layout icon. A small
underline marks focus; occupancy and visibility control brightness. The
optional `accentFocused` setting marks focus with the theme's accent colour
and bold instead of the underline, still without backgrounds or borders. Keep the
separate hyprmoncfg monitor panel's original icon.

Order groups left to right, then top to bottom when their horizontal positions
match. This orders the presentation only, never assignments or workspace IDs.
Right-click opens the spatial overview, where proportions, offsets, rotation
and stacked screens follow the actual layout. Overflow remains available there.
Clicking a number focuses that exact global ID. Scrolling a monitor group
starts from its visible workspace and stops at that group's ends. Sideways
scrolling counts too: right moves to the next workspace, as down does.

Under hyprmoncfg's per display strategy (`per_display_workspaces` in the
status), the bar looks and works like Omarchy's stock workspace widget, whose
logic it mirrors, fed by hyprmoncfg rather than Omarchy's state file. Each
bar shows only its own display's block as slots 1-9 and 0: the first five
(never more than the display's slots), any others that exist, then guests
after a 6-pixel gap, in the same 20-pixel slots. Instead of stock's layout
glyph, each bar highlights the workspace its display shows, focused or not,
with the underline or, with `accentFocused`, the accent colour and bold.
Clicking it just focuses it; Super + L still cycles layouts. A slot click dispatches Omarchy's own focus
when Omarchy runs the workspaces, otherwise the real ID, so it also works on
Omarchy before 4.5, where hyprmoncfg runs them. Right-click keeps the overview.

The daemon supplies a read-only workspace plan through its existing status
subscription. Quickshell supplies current locations, focus and occupancy.
Current locations override the plan. Switching goes directly to Hyprland,
including while the daemon is disconnected. The widget never changes ownership,
monitor configuration, saved profiles or keyboard shortcuts. The classic global
widget and stock Omarchy widget remain independent choices.
