import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "WorkspaceModel.js" as Model
import "PanelSetup.js" as Setup

BarWidget {
  id: root
  moduleName: "crmne.hyprmoncfg-workspaces"
  readonly property var service: {
    var shell = root.bar ? root.bar.shell : null
    return shell && typeof shell.serviceFor === "function" ? shell.serviceFor(root.moduleName) : null
  }
  readonly property var document: root.service ? root.service.document : ({})
  readonly property bool planAvailable: root.service && root.service.ready && Array.isArray(root.document.workspace_plan)
  readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  readonly property var groups: Model.groups(root.document, Hyprland.monitors.values, Hyprland.workspaces.values, root.focusedId)
  readonly property int limit: Math.max(1, Math.min(12, Number(root.setting("maxVisiblePerMonitor", 5)) || 5))
  readonly property bool opened: popup.open
  property bool popoutSwitchClosing: false
  property real wheelAccumulator: 0
  property string wheelMonitor: ""
  property bool plannerOpening: false
  property string panelSetupState: "unknown"
  readonly property string setupScript: decodeURIComponent(String(Qt.resolvedUrl("scripts/setup-panel.rb")).replace(/^file:\/\//, ""))
  // The planner remains the panel's real editor, including its preview guard.
  property var plannerLauncher: function(origin) {
    plannerRequest.command = ["omarchy-shell", "crmne.hyprmoncfg.editor", "workspaces", JSON.stringify(origin)]
    plannerRequest.running = true
  }
  // The compositor boundary is injectable for real-QML interaction tests.
  property var workspaceDispatcher: function(request) { Hyprland.dispatch(request) }

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  function plannerOrigin() {
    var window = root.QsWindow.window
    var origin = {screen: window && window.screen ? window.screen.name : (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")}
    if (window && root.width > 0 && root.height > 0) {
      var point = root.mapToItem(window.contentItem,0,0)
      origin.x=point.x; origin.y=point.y; origin.width=root.width; origin.height=root.height
    }
    return origin
  }
  function open() {
    if (root.plannerOpening) return
    overview.keyboardId = root.focusedId
    root.plannerOpening = true
    root.plannerLauncher(root.plannerOrigin())
  }
  function finishPlannerOpen(success) {
    if (!root.plannerOpening) return
    root.plannerOpening = false
    if (!success) popup.open = true
  }
  function close() { root.plannerOpening = false; popup.open = false }
  function setupPanel() {
    var action = Setup.action(root.panelSetupState)
    if (action === "retry") { root.open(); return }
    var origin = JSON.stringify(root.plannerOrigin())
    root.close()
    if (action === "open") {
      plannerInstaller.command = ["omarchy-shell", "shell", "summon", "crmne.hyprmoncfg", "{}"]
    } else {
      plannerInstaller.command = ["omarchy", "launch", "floating", "terminal", "with", "presentation",
        "ruby " + Util.shellQuote(root.setupScript) + " " + action + " " + Util.shellQuote(origin)]
    }
    Qt.callLater(function() { plannerInstaller.startDetached() })
  }
  function closeForPopoutSwitch() { root.close() }
  function toggleOverview(name) {
    overview.selectedName = name || ""
    if (popup.open) root.close()
    else root.open()
  }
  function focusWorkspace(id) {
    var request = Model.focusRequest(id, Hyprland.usingLua)
    if (request) {
      root.close()
      root.workspaceDispatcher(request)
    }
  }
  function scrollWorkspaces(delta, name) {
    if (root.wheelMonitor !== name) { root.wheelAccumulator = 0; root.wheelMonitor = name }
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (!wheel.steps) return
    var id = Model.neighbour(root.groups, root.focusedId, wheel.steps < 0 ? 1 : -1, name)
    if (id !== null && id !== root.focusedId) root.focusWorkspace(id)
  }
  function refresh() { Hyprland.refreshMonitors(); Hyprland.refreshWorkspaces() }
  // Quickshell performs its initial discovery. An eager refresh here can race
  // that request and suppress creation of its initial monitor objects.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (["workspacev2", "focusedmon", "focusedmonv2", "moveworkspacev2", "changeworkspaceid", "configreloaded", "monitoraddedv2", "monitorremoved"].indexOf(name) >= 0) root.refresh()
    }
  }
  ShellIpc {
    target: "crmne.hyprmoncfg-workspaces"
    function open(): void { root.open() }
    function close(): void { root.broadcast("close") }
    function toggle(): void { root.toggleOverview("") }
    function refresh(): void { root.broadcast("refresh") }
  }

  Process {
    id: plannerRequest
    stdout: StdioCollector { id: plannerOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (!root.plannerOpening) return
      if (exitCode === 0 && plannerOutput.text.trim() === "ok") root.finishPlannerOpen(true)
      else panelProbe.running = true
    }
  }
  Process {
    id: panelProbe
    command: ["timeout", "5s", "omarchy", "plugin", "list", "--json"]
    stdout: StdioCollector { id: panelOutput; waitForEnd: true }
    onExited: function(exitCode) {
      root.panelSetupState = Setup.state(panelOutput.text, exitCode, plannerOutput.text.trim())
      root.finishPlannerOpen(false)
    }
  }
  Process { id: plannerInstaller }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  implicitWidth: root.vertical ? root.barSize : row.implicitWidth + root.trailingGap
  implicitHeight: root.vertical ? row.implicitHeight : root.barSize
  GridLayout {
    id: row
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.groups.length)
    // Match the stock widget: 20px slots, 1px between numbers, and its
    // existing 6px separator between workspace groups.
    columnSpacing: Style.space(1) + Style.space(6)
    rowSpacing: Style.space(2) + Style.space(6)
    Repeater {
      model: root.groups
      Item {
        id: group
        required property var modelData
        implicitWidth: numbers.implicitWidth
        implicitHeight: numbers.implicitHeight
        GridLayout {
          id: numbers
          anchors.centerIn: parent
          columns: root.vertical ? 1 : Math.max(1, Math.min(root.limit, group.modelData.workspaces.length) + (more.visible ? 1 : 0))
          columnSpacing: Style.space(1); rowSpacing: Style.space(2)
          Repeater {
            model: group.modelData.workspaces.slice(0, root.limit)
            WorkspaceChip {
              required property var modelData
              bar: root.bar
              workspaceInfo: modelData
              displayName: Model.plain(group.modelData.name)
              onChosen: function(id) { root.focusWorkspace(id) }
              onOverviewRequested: root.toggleOverview(group.modelData.name)
              onWheelMoved: function(delta) { root.scrollWorkspaces(delta, group.modelData.name) }
            }
          }
          WidgetButton {
            id: more
            visible: group.modelData.workspaces.length > root.limit || group.modelData.workspaces.length === 0
            bar: root.bar
            text: group.modelData.workspaces.length > root.limit ? "+" + (group.modelData.workspaces.length - root.limit) : "·"
            fixedWidth: Style.space(28); fixedHeight: root.barSize
            tooltipText: strings.t("more").arg(Model.plain(group.modelData.name))
            onPressed: function(button) { if (button === Qt.LeftButton) root.toggleOverview(group.modelData.name) }
          }
        }
      }
    }
  }
  KeyboardPanel {
    id: popup
    anchorItem: root
    owner: root
    bar: root.bar
    contentWidth: Math.min(Style.space(560), (root.QsWindow.window ? root.QsWindow.window.screen.width : 900) - Style.space(50))
    contentHeight: fittedContentHeight(overview.implicitHeight)
    focusTarget: overview
    WorkspaceOverview {
      id: overview
      width: parent.width
      height: implicitHeight
      groups: root.groups
      focusedId: root.focusedId
      planAvailable: root.planAvailable
      panelSetupState: root.panelSetupState
      canvasHeight: Math.min(Style.space(230), (root.QsWindow.window ? root.QsWindow.window.screen.height : 800) * 0.35)
      onChosen: function(id) { root.focusWorkspace(id) }
      onCloseRequested: root.close()
      onConfigureRequested: root.setupPanel()
    }
  }
}
