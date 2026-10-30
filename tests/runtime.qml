import QtQuick
import Quickshell
import Quickshell.Hyprland
import "." as Plugin
import "WorkspaceModel.js" as Model

ShellRoot {
  id: root
  property var commands: []
  QtObject {
    id: host
    property bool vertical: false
    property int barSize: 26
    property string position: "top"
    property string fontFamily: "sans-serif"
    property color barForeground: "white"
    property color urgent: "red"
    property bool foregroundAnimationEnabled: false
    property var shell: shellHost
    function hideTooltip(item) {}
    function registerClickTarget(item) {}
    function unregisterClickTarget(item) {}
    function moduleWidgets(id) { return [widget] }
    function run(command) { root.commands.push(command) }
  }
  QtObject {
    id: shellHost
    function serviceFor(id) { return fakeService }
  }
  QtObject { id: fakeService; property var document: ({}); property bool ready: false }
  Plugin.Workspaces {
    id: widget
    bar: host
    workspaceDispatcher: function(request) { root.commands.push(request) }
  }
  // It only subscribes to the local daemon, and has no mutation API.
  Plugin.WorkspaceService { id: service }

  function assert(value, message) { if (!value) throw new Error(message) }
  function chips(item, result) {
    if (item.workspaceInfo && typeof item.triggerPress === "function") result.push(item)
    var children = item.children || []
    for (var i = 0; i < children.length; i++) chips(children[i], result)
  }
  function testScroll() {
    try {
      var group = widget.groups.filter(function(group) { return group.focused })[0]
      root.assert(group && group.workspaces.length >= 3, "assigned empty workspaces missing")
      root.commands = []
      widget.scrollWorkspaces(-60, group.name)
      root.assert(root.commands.length === 0, "partial wheel delta switched early")
      widget.scrollWorkspaces(-60, group.name)
      var target = Model.neighbour(widget.groups, widget.focusedId, 1, group.name)
      root.assert(root.commands.length === 1 && root.commands[0] === Model.focusRequest(target, Hyprland.usingLua), "accumulated wheel delta switched the wrong workspace")
      console.log("WORKSPACES_PASS")
    } catch (error) { console.error("WORKSPACES_FAIL: " + error) }
    Qt.quit()
  }
  Timer {
    interval: 500; running: true; repeat: true
    onTriggered: {
      if (!widget.groups.length) return
      stop()
      try {
        var buttons = []; root.chips(widget, buttons)
        root.assert(buttons.length > 0, "no live workspace buttons without a daemon plan")
        for (var i = 0; i < buttons.length; i++) {
          root.commands = []
          buttons[i].triggerPress(Qt.LeftButton)
          root.assert(root.commands.length === 1, "button did not dispatch exactly once")
          root.assert(root.commands[0].indexOf(String(buttons[i].workspaceInfo.id)) >= 0, "button renumbered the workspace")
        }
        root.commands = []
        widget.focusWorkspace('4; bad')
        root.assert(root.commands.length === 0, "unsafe ID dispatched")
        var first = buttons[0].workspaceInfo.id
        widget.focusWorkspace(first)
        root.assert(root.commands.length === 1, "daemon absence blocked focus")
        service.requestId = "qa"
        service.eventSinceRequest = false
        service.document = {schema_version:1, monitors:[], marker:"kept"}
        service.receive(JSON.stringify({type:"response", protocol_version:1, id:"stale", result:{schema_version:1, monitors:[]}}))
        root.assert(service.document.marker === "kept", "stale request response accepted")
        service.ready = false
        service.receive(JSON.stringify({type:"response", protocol_version:1, id:"qa", result:{schema_version:1, monitors:[], workspace_plan:[]}}))
        root.assert(service.ready && Array.isArray(service.document.workspace_plan), "valid status rejected")
        service.receive('{invalid')
        root.assert(service.ready, "malformed status discarded the working state")
        service.receive(JSON.stringify({type:"event", protocol_version:1, event:"status", data:{schema_version:1, monitors:[], marker:"new"}}))
        service.receive(JSON.stringify({type:"response", protocol_version:1, id:"qa", result:{schema_version:1, monitors:[], marker:"old"}}))
        root.assert(service.document.marker === "new", "late snapshot replaced newer event")

        var monitor = Hyprland.focusedMonitor
        var raw = monitor.lastIpcObject
        fakeService.document = {schema_version:1,
          monitors:[{name:monitor.name, key:"test-display", make:raw.make, model:raw.model, serial:raw.serial}],
          workspace_plan:[{output_name:monitor.name, output_key:"test-display", workspaces:["900001", "900002", "900003"]}]}
        Qt.callLater(root.testScroll)
      } catch (error) { console.error("WORKSPACES_FAIL: " + error); Qt.quit() }
    }
  }
}
