import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "WorkspaceModel.js" as Model

Item {
  id: root
  property var groups: []
  property bool planAvailable: false
  property string panelSetupState: "unknown"
  property int focusedId: -1
  property string selectedName: ""
  property int keyboardId: focusedId
  property real canvasHeight: Style.space(230)
  signal chosen(int workspaceId)
  signal configureRequested()
  signal closeRequested()
  readonly property var rectangles: Model.rectangles(groups, width, canvasHeight, Style.space(8))
  readonly property var selectedGroup: {
    for (var i = 0; i < groups.length; i++) if (groups[i].name === selectedName) return groups[i]
    return groups.length ? groups[0] : null
  }
  readonly property var selectedRectangle: {
    for (var i = 0; i < rectangles.length; i++) if (selectedGroup && rectangles[i].screen.name === selectedGroup.name) return rectangles[i]
    return null
  }
  function capacity(rect) {
    return rect ? Math.max(0, Math.floor((rect.width - Style.space(16)) / Style.space(38)))
      * Math.max(0, Math.floor((rect.height - Style.space(34)) / Style.space(34))) : 0
  }
  readonly property bool showTray: selectedGroup !== null && selectedGroup.workspaces.length > capacity(selectedRectangle)
  implicitHeight: title.implicitHeight + Style.space(18) + canvasHeight
    + (showTray ? Style.space(90) : 0) + footer.implicitHeight + Style.space(18)
  focus: true

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function moveCursor(direction) {
    var id = Model.neighbour(root.groups, root.keyboardId, direction, "")
    if (id !== null) root.keyboardId = id
  }
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) { root.closeRequested(); event.accepted = true }
    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { root.moveCursor(-1); event.accepted = true }
    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) { root.moveCursor(1); event.accepted = true }
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      if (Model.workspaceId(root.keyboardId) !== null) root.chosen(root.keyboardId)
      event.accepted = true
    }
  }

  Text {
    id: title
    text: strings.t("overview")
    textFormat: Text.PlainText
    color: Commons.Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.title
  }

  Item {
    id: stage
    y: title.height + Style.space(18)
    width: root.width; height: root.canvasHeight
    Repeater {
      model: root.rectangles
      Rectangle {
        id: card
        required property var modelData
        readonly property var screen: modelData.screen
        readonly property int capacity: root.capacity(modelData)
        x: modelData.x; y: modelData.y; width: modelData.width; height: modelData.height
        radius: Style.space(6)
        color: Util.alpha(Commons.Color.foreground, screen.focused ? 0.085 : 0.035)
        border.color: screen.focused ? Commons.Color.foreground : Util.alpha(Commons.Color.foreground, 0.25)
        border.width: screen.focused ? 2 : 1
        clip: true
        MouseArea {
          anchors.fill: parent
          onClicked: root.selectedName = card.screen.name
        }
        Text {
          x: Style.space(10); y: Style.space(7)
          width: parent.width - Style.space(20)
          visible: parent.width >= Style.space(65) && parent.height >= Style.space(28)
          text: Model.plain(card.screen.name)
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Util.alpha(Commons.Color.foreground, 0.7)
          font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        Flow {
          x: Style.space(8); y: Style.space(30)
          width: parent.width - Style.space(16)
          spacing: Style.space(4)
          Repeater {
            model: card.screen.workspaces.slice(0, Math.max(0, card.capacity))
            WorkspaceChip {
              required property var modelData
              workspaceInfo: modelData
              displayName: Model.plain(card.screen.name)
              keyboardSelected: root.activeFocus && root.keyboardId === modelData.id
              fixedWidth: Style.space(34)
              onChosen: function(id) { root.chosen(id) }
            }
          }
        }
        Rectangle {
          visible: card.screen.workspaces.length > card.capacity
          width: Style.space(22); height: Style.space(18); radius: 3
          anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: Style.space(4)
          color: Commons.Color.background
          Text { anchors.centerIn: parent; text: "…"; textFormat: Text.PlainText; color: Commons.Color.foreground }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedName = card.screen.name }
        }
      }
    }
    Text {
      anchors.centerIn: parent
      visible: root.groups.length === 0
      text: strings.t("empty"); textFormat: Text.PlainText
      color: Commons.Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body
    }
  }

  Item {
    id: tray
    y: stage.y + stage.height + Style.space(8)
    width: root.width; height: root.showTray ? Style.space(82) : 0
    visible: root.showTray
    Text {
      id: trayTitle
      text: root.selectedGroup ? Model.plain(root.selectedGroup.name) : ""
      textFormat: Text.PlainText; color: Commons.Color.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    Flickable {
      y: trayTitle.height + Style.space(6); width: parent.width; height: parent.height - y
      contentHeight: trayFlow.height; clip: true
      ScrollBar.vertical: ScrollBar {}
      Flow {
        id: trayFlow
        width: parent.width; spacing: Style.space(4)
        Repeater {
          model: root.selectedGroup ? root.selectedGroup.workspaces : []
          WorkspaceChip {
            required property var modelData
            workspaceInfo: modelData
            displayName: root.selectedGroup ? Model.plain(root.selectedGroup.name) : ""
            onChosen: function(id) { root.chosen(id) }
          }
        }
      }
    }
  }
  Column {
    id: footer
    y: stage.y + stage.height + (root.showTray ? Style.space(90) : 0) + Style.space(12)
    width: root.width; spacing: Style.space(8)
    Text {
      visible: !root.planAvailable
      width: parent.width
      text: strings.t("liveOnly"); textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      font.family: Style.font.family; font.pixelSize: Style.font.caption
      color: Util.alpha(Commons.Color.foreground, 0.65)
    }
    Text {
      width: parent.width
      text: strings.t("setup." + root.panelSetupState); textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      font.family: Style.font.family; font.pixelSize: Style.font.caption
      color: Util.alpha(Commons.Color.foreground, 0.65)
    }
    Button {
      text: root.panelSetupState === "unavailable" ? "hyprmoncfg" : strings.t("setupAction." + root.panelSetupState)
      tooltipText: root.panelSetupState === "unavailable" ? strings.t("configure") : ""
      focusable: true
      onClicked: root.configureRequested()
    }
  }
}
