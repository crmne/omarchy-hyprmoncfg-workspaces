import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import "." as Plugin
import "WorkspaceModel.js" as Model

ShellRoot {
  id: root
  property var commands: []
  property var plannerRequests: []
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
    plannerLauncher: function(origin) { root.plannerRequests.push(origin) }
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
      root.withPerDisplay({block_size: 10, slots: 10})
      Qt.callLater(root.testPerDisplayLabels)
    } catch (error) { console.error("WORKSPACES_FAIL: " + error); Qt.quit() }
  }
  property var groupedDocument: ({})
  function withPerDisplay(value) {
    var next = {}
    for (var key in root.groupedDocument) next[key] = root.groupedDocument[key]
    if (value) next.per_display_workspaces = value
    fakeService.document = next
  }
  function find(predicate) {
    var buttons = []; root.chips(widget, buttons)
    return buttons.filter(predicate)
  }
  // Like Omarchy's stock widget: only this display's block, by slot, with
  // the workspaces visiting it after a gap.
  function testPerDisplayLabels() {
    try {
      var monitor = Hyprland.focusedMonitor
      root.assert(widget.perDisplay !== null && !widget.perDisplay.delegate, "per display status not recognised")
      root.withPerDisplay({block_size: 10, slots: 3, blocks: [{output_name: monitor.name, block: 90000}]})
      var buttons = root.find(function() { return true })
      var ids = buttons.map(function(b) { return b.workspaceInfo.id })
      root.assert(ids[0] === 900001 && ids[1] === 900002 && ids[2] === 900003 && ids.indexOf(900004) === -1, "per display bar did not show its block's first slots: " + ids)
      root.assert(buttons[0].text === "1" && buttons[1].text === "2" && buttons[2].tooltipText.indexOf("3 · ") === 0, "per display workspace not labelled by its slot")
      root.assert(buttons[0].width === buttons[0].fixedWidth && buttons[0].opacity < 1, "empty slot not dimmed at the stock size")
      root.assert(widget.displayIds.length === buttons.length, "grouped numbers still shown in per display mode")
      var guests = buttons.filter(function(b) { return b.workspaceInfo.guest })
      root.assert(guests.length === buttons.length - 3 && guests.length > 0, "workspaces on this display not shown as guests")
      root.assert(guests[0].workspaceInfo.firstGuest, "guests not set apart")
      root.commands = []
      buttons[1].triggerPress(Qt.LeftButton)
      root.assert(root.commands.length === 1 && root.commands[0] === Model.focusRequest(900002, Hyprland.usingLua), "own slot did not focus its real workspace: " + root.commands)
      var shown = buttons.filter(function(b) { return b.workspaceInfo.visible })[0]
      root.assert(shown && shown.workspaceInfo.id === widget.activeWorkspaceId, "shown workspace missing")
      var other = guests.filter(function(b) { return !b.workspaceInfo.visible })[0]
      if (other) {
        root.commands = []
        other.triggerPress(Qt.LeftButton)
        root.assert(root.commands[0] === Model.focusRequest(other.workspaceInfo.id, Hyprland.usingLua), "guest not focused by its ID")
      }
      root.assert(buttons.every(function(b) { return b.pointerArea !== null }), "sideways scrolling has no mouse area to listen to")
      root.commands = []
      widget.scrollDisplay(-60)
      root.assert(root.commands.length === 0, "partial wheel delta switched early")
      widget.scrollDisplay(-60)
      var target = Model.displayScrollTarget(widget.displayIds, widget.activeWorkspaceId, -1)
      root.assert(target === null ? root.commands.length === 0 : root.commands[0] === Model.focusRequest(target, Hyprland.usingLua), "scroll did not move along this display's row")
      root.commands = []
      widget.scrollDisplay(240)
      target = Model.displayScrollTarget(widget.displayIds, widget.activeWorkspaceId, 1)
      root.assert(target !== null && root.commands.length === 1 && root.commands[0] === Model.focusRequest(target, Hyprland.usingLua), "scroll did not move back along the row")

      root.withPerDisplay({block_size: 10, slots: 3, delegate: "omarchy", blocks: [{output_name: monitor.name, block: 90000}]})
      buttons = root.find(function() { return true })
      root.commands = []
      buttons[2].triggerPress(Qt.LeftButton)
      var expected = Hyprland.usingLua ? 'o.workspaces.focus(3, "' + monitor.name + '")' : Model.focusRequest(900003, false)
      root.assert(root.commands.length === 1 && root.commands[0] === expected, "delegated slot not dispatched as Omarchy does: " + root.commands)

      var requests = root.plannerRequests.length
      buttons[0].triggerPress(Qt.RightButton)
      root.assert(root.plannerRequests.length === requests + 1, "right-click did not open the planner")
      widget.finishPlannerOpen(true)

      // The workspace this display shows is marked, whether or not it has
      // focus: underlined, or accented with accentFocused. Others are not.
      var shown = root.find(function(b) { return b.workspaceInfo.visible })[0]
      var plain = root.find(function(b) { return !b.workspaceInfo.visible })[0]
      root.assert(shown.highlighted && shown.text === shown.label && shown.fixedWidth === Style.space(20), "shown workspace not a plain highlighted 20px number")
      root.assert(!plain.highlighted && Qt.colorEqual(shown.foreground, Commons.Color.foreground), "highlight on the wrong workspace or accented with the setting off")
      root.commands = []
      shown.triggerPress(Qt.LeftButton)
      root.assert(root.commands.length === 1 && root.commands[0] === Model.displayFocusRequest(widget.perDisplay, widget.displayBlock, widget.monitorName, shown.workspaceInfo.id, Hyprland.usingLua), "clicking the shown workspace did not just focus it: " + root.commands)
      widget.settings = {accentFocused: true}
      root.assert(Qt.colorEqual(shown.foreground, Commons.Color.accent) && shown.weightedLabel.font.weight === Font.Bold, "accentFocused did not mark the shown workspace")
      root.assert(Qt.colorEqual(plain.foreground, Commons.Color.foreground) && plain.weightedLabel.font.weight === Font.Normal, "accentFocused marked another workspace")
      widget.settings = {}
      root.withPerDisplay(null)
      Qt.callLater(root.testGroupedAgain)
    } catch (error) { console.error("WORKSPACES_FAIL: " + error); Qt.quit() }
  }
  function testGroupedAgain() {
    try {
      var planned = root.find(function(b) { return b.workspaceInfo.id === 900002 })[0]
      root.assert(planned && planned.text === "900002" && widget.displayIds.length === 0, "grouped view not restored without per_display_workspaces")
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
        var focusedChip = buttons.filter(function(b) { return b.workspaceInfo.focused })[0]
        var otherChip = buttons.filter(function(b) { return !b.workspaceInfo.focused })[0]
        root.assert(focusedChip, "no focused workspace button")
        root.assert(focusedChip.weightedLabel !== null, "LabelWeight did not find WidgetButton's label")
        root.assert(Qt.colorEqual(focusedChip.foreground, Commons.Color.foreground) && focusedChip.weightedLabel.font.weight === Font.Normal, "focus was accented with the setting off")
        widget.settings = {accentFocused: true}
        root.assert(Qt.colorEqual(focusedChip.foreground, Commons.Color.accent), "accentFocused did not colour the focused workspace")
        root.assert(focusedChip.weightedLabel.font.weight === Font.Bold, "accentFocused did not set the focused workspace in bold")
        if (otherChip) root.assert(Qt.colorEqual(otherChip.foreground, Commons.Color.foreground) && otherChip.weightedLabel.font.weight === Font.Normal, "accentFocused styled an unfocused workspace")
        widget.settings = {}
        root.assert(focusedChip.weightedLabel.font.weight === Font.Normal, "turning accentFocused off kept the bold")
        widget.open()
        root.assert(root.plannerRequests.length === 1 && root.plannerRequests[0].screen, "picker did not request the full planner on its monitor")
        widget.finishPlannerOpen(true)
        root.assert(!widget.opened, "successful planner launch also opened the fallback popup")
        widget.open()
        widget.close()
        widget.finishPlannerOpen(false)
        root.assert(!widget.opened, "a late launch failure reopened a dismissed popup")
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
        root.groupedDocument = {schema_version:1,
          monitors:[{name:monitor.name, key:"test-display", make:raw.make, model:raw.model, serial:raw.serial}],
          workspace_plan:[{output_name:monitor.name, output_key:"test-display", workspaces:["900001", "900002", "900003"]}]}
        fakeService.document = root.groupedDocument
        Qt.callLater(root.testScroll)
      } catch (error) { console.error("WORKSPACES_FAIL: " + error); Qt.quit() }
    }
  }
}
