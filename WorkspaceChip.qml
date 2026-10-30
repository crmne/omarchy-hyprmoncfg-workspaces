import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

WidgetButton {
  id: root
  property var workspaceInfo: ({ id: 1, focused: false, visible: false, occupied: false })
  property string displayName: ""
  property bool keyboardSelected: false
  signal chosen(int workspaceId)
  signal overviewRequested()
  text: String(workspaceInfo.id)
  fixedWidth: vertical ? barSize : Style.space(Math.max(20, text.length * 8 + 8))
  fixedHeight: bar ? bar.barSize : Style.space(28)
  horizontalMargin: 6
  verticalPadding: 6
  foreground: Commons.Color.foreground
  opacity: workspaceInfo.focused || workspaceInfo.visible || workspaceInfo.occupied || workspaceInfo.urgent ? 1 : 0.5
  tooltipText: String(workspaceInfo.id) + " · " + displayName
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

  Rectangle {
    visible: root.workspaceInfo.focused || root.keyboardSelected || root.activeFocus
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
