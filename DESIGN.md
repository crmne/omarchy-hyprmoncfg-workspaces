# Workspace presentation

The bar stays as quiet and compact as Omarchy's own workspace widget. Use
plain global numbers, standard 20-pixel slots and 1-pixel spacing, plus the
standard 6-pixel separator between monitor groups. Scale these values through
Omarchy's theme. No group backgrounds, borders, or extra layout icon. A small
underline marks focus; occupancy and visibility control brightness. Keep the
separate hyprmoncfg monitor panel's original icon.

Order groups left to right, then top to bottom when their horizontal positions
match. This orders the presentation only, never assignments or workspace IDs.
Right-click opens the spatial overview, where proportions, offsets, rotation
and stacked screens follow the actual layout. Overflow remains available there.
Clicking a number focuses that exact global ID. Scrolling a monitor group starts
from its visible workspace and stops at that group's ends.

The daemon supplies a read-only workspace plan through its existing status
subscription. Quickshell supplies current locations, focus and occupancy.
Current locations override the plan. Switching goes directly to Hyprland,
including while the daemon is disconnected. The widget never changes ownership,
monitor configuration, saved profiles or keyboard shortcuts. The classic global
widget and stock Omarchy widget remain independent choices.
