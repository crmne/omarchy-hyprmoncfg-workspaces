import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

WidgetButton {
  id: root
  property var workspaceInfo: ({ id: 1, focused: false, visible: false, occupied: false })
  property string displayName: ""
  property bool keyboardSelected: false
  // Marks the focused workspace with the theme's accent colour and bold
  // instead of the underline.
  property bool accentFocused: false
  // The workspace marked as current: the focused one in the grouped view, and
  // each display's shown one in per display mode.
  property bool highlighted: workspaceInfo.focused === true
  readonly property bool accented: accentFocused && highlighted
  readonly property alias weightedLabel: labelWeight.label
  signal chosen(int workspaceId)
  signal overviewRequested()
  // The slot within its display's block under the per display strategy,
  // otherwise the global ID. Clicking always focuses the real ID.
  readonly property string label: workspaceInfo.label !== undefined ? String(workspaceInfo.label) : String(workspaceInfo.id)
  text: label
  fixedWidth: vertical ? barSize : Style.space(Math.max(20, text.length * 8 + 8))
  fixedHeight: bar ? bar.barSize : Style.space(28)
  horizontalMargin: 6
  verticalPadding: 6
  foreground: accented ? Commons.Color.accent : Commons.Color.foreground
  opacity: workspaceInfo.focused || workspaceInfo.visible || workspaceInfo.occupied || workspaceInfo.urgent ? 1 : 0.5
  tooltipText: label + " · " + displayName
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: tooltipText
  Accessible.onPressAction: root.chosen(root.workspaceInfo.id)
  onPressed: function(button) {
    if (button === Qt.LeftButton) root.chosen(root.workspaceInfo.id)
    else if (button === Qt.RightButton) root.overviewRequested()
  }
  Keys.onReturnPressed: root.chosen(root.workspaceInfo.id)
  Keys.onSpacePressed: root.chosen(root.workspaceInfo.id)

  // WidgetButton passes on only vertical scrolling. A sideways swipe or a
  // tilted wheel moves along the row too: right to the next workspace, as
  // scrolling down does.
  readonly property Item pointerArea: {
    var kids = root.children
    for (var i = 0; i < kids.length; i++) {
      if (String(kids[i]).indexOf("QQuickMouseArea") === 0) return kids[i]
    }
    return null
  }
  Connections {
    target: root.pointerArea
    function onWheel(wheel) {
      if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) root.wheelMoved(wheel.angleDelta.x)
    }
  }

  LabelWeight {
    id: labelWeight
    button: root
    weight: root.accented ? Font.Bold : Font.Normal
  }

  Rectangle {
    visible: (root.highlighted && !root.accented) || root.keyboardSelected || root.activeFocus
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.bar ? 2 : 0
    width: Style.space(8); height: 1
    color: Commons.Color.foreground
  }
  Rectangle {
    visible: root.workspaceInfo.urgent === true
    width: Style.space(4); height: width; radius: width / 2
    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 2
    color: Commons.Color.accent
  }
}
