// Presentation only. Assignments arrive from hyprmoncfg; live Hyprland state wins.
function workspaceId(value) {
  var text = String(value)
  if (!/^[1-9][0-9]*$/.test(text)) return null
  var id = Number(text)
  return Number.isSafeInteger(id) && id <= 2147483647 ? id : null
}

function plain(value) { return String(value || "").slice(0, 160).replace(/[<>\u0000-\u001f\u007f]/g, "") }
function finite(value, fallback) { var n = Number(value); return isFinite(n) ? n : fallback }

function liveScreens(values) {
  var result = []
  for (var i = 0; i < values.length; i++) {
    var monitor = values[i], raw = monitor.lastIpcObject || monitor
    if (!monitor.name || monitor.name === "FALLBACK" || raw.disabled || (raw.mirrorOf && raw.mirrorOf !== "none")) continue
    var scale = Math.max(0.1, finite(monitor.scale, 1))
    var width = finite(raw.width, 0), height = finite(raw.height, 0)
    if (Number(raw.transform || 0) % 2) { var swap = width; width = height; height = swap }
    if (!(width > 0 && height > 0)) continue
    result.push({ name: String(monitor.name), key: String(monitor.name),
      description: plain(monitor.description || raw.description || monitor.name),
      serial: String(raw.serial || ""), make: String(raw.make || ""), model: String(raw.model || ""),
      x: finite(monitor.x, 0), y: finite(monitor.y, 0), width: width / scale, height: height / scale,
      focused: monitor.focused === true,
      visibleId: workspaceId(monitor.activeWorkspace ? monitor.activeWorkspace.id : null),
      sleeping: raw.dpmsStatus === false, workspaces: [] })
  }
  return result.sort(function(a, b) { return a.x - b.x || a.y - b.y || a.name.localeCompare(b.name) })
}

function matchesIdentity(screen, saved) {
  if (!saved || screen.name !== saved.name) return false
  return ["serial", "make", "model"].every(function(field) {
    return !screen[field] || !saved[field] || screen[field] === String(saved[field])
  })
}

function groups(document, monitors, workspaces, focusedId) {
  var screens = liveScreens(monitors), byName = {}, byKey = {}, assigned = {}, live = {}
  var summaries = document && Array.isArray(document.monitors) ? document.monitors : []
  screens.forEach(function(screen) {
    byName[screen.name] = screen
    for (var i = 0; i < summaries.length; i++) {
      if (matchesIdentity(screen, summaries[i])) {
        screen.key = String(summaries[i].key || screen.name)
        byKey[screen.key] = screen
        break
      }
    }
  })
  var plan = document && Array.isArray(document.workspace_plan) ? document.workspace_plan : []
  plan.forEach(function(group) {
    var screen = byKey[group.output_key]
    if (!screen || screen.name !== group.output_name || !Array.isArray(group.workspaces)) return
    group.workspaces.forEach(function(value) { var id = workspaceId(value); if (id !== null) assigned[id] = screen.name })
  })
  workspaces.forEach(function(workspace) {
    var id = workspaceId(workspace.id)
    if (id === null) return
    var name = typeof workspace.monitor === "string" ? workspace.monitor : workspace.monitor ? String(workspace.monitor.name) : ""
    // Existing workspaces always override a plan, including a temporarily
    // unknown destination during an unplug. Never show a false old location.
    assigned[id] = name
    var count = workspace.toplevels && workspace.toplevels.values ? workspace.toplevels.values.length : finite(workspace.windows, 0)
    live[id] = { occupied: count > 0, urgent: workspace.urgent === true }
  })
  screens.forEach(function(screen) {
    if (screen.visibleId !== null && assigned[screen.visibleId] === undefined) assigned[screen.visibleId] = screen.name
  })
  Object.keys(assigned).forEach(function(value) {
    var screen = byName[assigned[value]], id = Number(value)
    if (screen) screen.workspaces.push({ id: id, occupied: !!(live[id] && live[id].occupied),
      urgent: !!(live[id] && live[id].urgent), focused: id === focusedId, visible: id === screen.visibleId })
  })
  screens.forEach(function(screen) {
    screen.workspaces.sort(function(a, b) { return a.id - b.id })
    // Quickshell exposes the focused monitor separately, not as .focused
    // on every monitor. Its focused workspace is already reactive here.
    screen.focused = screen.workspaces.some(function(workspace) { return workspace.focused })
  })
  return screens
}

function bounds(screens) {
  if (!screens.length) return { x: 0, y: 0, width: 1, height: 1 }
  var left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity
  screens.forEach(function(screen) {
    left = Math.min(left, screen.x); top = Math.min(top, screen.y)
    right = Math.max(right, screen.x + screen.width); bottom = Math.max(bottom, screen.y + screen.height)
  })
  return { x: left, y: top, width: Math.max(1, right - left), height: Math.max(1, bottom - top) }
}

function rectangles(screens, width, height, gap) {
  var box = bounds(screens), scale = Math.max(0, Math.min(width / box.width, height / box.height))
  var dx = (width - box.width * scale) / 2, dy = (height - box.height * scale) / 2
  return screens.map(function(screen) {
    var w = screen.width * scale, h = screen.height * scale
    var inset = Math.min(gap || 0, w / 5, h / 5)
    return { screen: screen, x: dx + (screen.x - box.x) * scale + inset / 2,
      y: dy + (screen.y - box.y) * scale + inset / 2, width: Math.max(1, w - inset), height: Math.max(1, h - inset) }
  })
}

function focusRequest(id, lua) {
  var value = workspaceId(id)
  if (value === null) return ""
  return lua ? 'hl.dsp.focus({ workspace = "' + value + '" })' : "workspace " + value
}

function neighbour(groups, focusedId, direction, monitorName) {
  var ids = []
  var visibleId = null
  groups.forEach(function(group) {
    if (monitorName && group.name !== monitorName) return
    if (monitorName) visibleId = group.visibleId
    group.workspaces.forEach(function(workspace) { ids.push(workspace.id) })
  })
  var index = ids.indexOf(focusedId)
  if (index < 0 && visibleId !== null) index = ids.indexOf(visibleId)
  if (!ids.length) return null
  if (index < 0) return direction > 0 ? ids[0] : ids[ids.length - 1]
  return ids[Math.max(0, Math.min(ids.length - 1, index + direction))]
}

if (typeof module !== "undefined") module.exports = { workspaceId, plain, liveScreens, groups, bounds, rectangles, focusRequest, neighbour }
