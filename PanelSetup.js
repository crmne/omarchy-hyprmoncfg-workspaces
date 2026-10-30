// Installation and enablement are different states. Never try to reinstall a
// disabled panel, or infer absence from a failed local discovery command.
function state(output, exitCode, routeReply) {
  if (exitCode !== 0 || typeof output !== "string" || output.length > 1048576) return "unknown"
  try {
    var entries = JSON.parse(output)
    if (!Array.isArray(entries)) return "unknown"
    var panel = entries.filter(function(entry) { return entry && entry.id === "crmne.hyprmoncfg" })[0]
    if (!panel) return "missing"
    if (panel.enabled !== true) return "disabled"
    return routeReply === "unavailable" ? "unavailable" : "outdated"
  } catch (_) { return "unknown" }
}

function action(status) {
  if (status === "missing") return "install"
  if (status === "disabled") return "enable"
  if (status === "outdated") return "update"
  if (status === "unavailable") return "open"
  return "retry"
}

if (typeof module !== "undefined") module.exports = {state: state, action: action}
