import QtQuick
import Quickshell
import Quickshell.Io

// One read-only subscription for all bars. Workspace actions go to Hyprland.
Item {
  id: root
  property var shell: null
  property var document: ({})
  property bool ready: false
  property int generation: 0
  property string requestId: ""
  property bool eventSinceRequest: false
  readonly property bool connected: socket.connected
  readonly property string runtimeDir: String(Quickshell.env("XDG_RUNTIME_DIR") || "")
  readonly property string socketPath: root.runtimeDir + "/hyprmoncfgd.sock"

  function subscribe() {
    root.generation++
    root.requestId = String(root.generation)
    root.eventSinceRequest = false
    socket.write(JSON.stringify({type: "request", protocol_version: 1, id: root.requestId, method: "subscribe"}) + "\n")
    socket.flush()
    responseTimeout.restart()
  }

  function receive(text) {
    if (text.length > 4 * 1024 * 1024) return
    try {
      var message = JSON.parse(text)
      if (message.protocol_version !== 1) return
      var value = null
      if (message.type === "response" && String(message.id) === root.requestId) {
        responseTimeout.stop()
        // A late snapshot must not replace an event already received.
        if (root.eventSinceRequest) return
        // Busy snapshots are retried without throwing away the last layout.
        if (message.error) { retrySubscribe.restart(); return }
        value = message.result
      } else if (message.type === "event" && message.event === "status") value = message.data
      if (!value || value.schema_version !== 1 || !Array.isArray(value.monitors)) return
      if (message.type === "event") {
        root.eventSinceRequest = true
        responseTimeout.stop()
        retrySubscribe.stop()
      }
      root.document = value
      root.ready = true
    } catch (_) { /* Ignore malformed messages; a later status repairs the view. */ }
  }

  Socket {
    id: socket
    path: root.socketPath
    connected: root.runtimeDir !== ""
    onConnectedChanged: {
      if (connected) root.subscribe()
      else { root.ready = false; responseTimeout.stop(); retrySubscribe.stop() }
    }
    parser: SplitParser { onRead: function(data) { root.receive(data) } }
    onError: function(error) { socket.connected = false }
  }
  Timer {
    interval: 2000
    repeat: true
    running: root.runtimeDir !== "" && !socket.connected
    onTriggered: socket.connected = true
  }
  Timer { id: retrySubscribe; interval: 700; onTriggered: if (socket.connected) root.subscribe() }
  Timer { id: responseTimeout; interval: 6000; onTriggered: socket.connected = false }
}
