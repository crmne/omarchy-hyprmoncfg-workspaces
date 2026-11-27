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
  // The unfinished line from the daemon. Quickshell's SplitParser would buffer
  // a line without limit before handing it over, so chunks arrive as read and
  // are split here, where the 4 MiB limit applies while the line is growing.
  property string pending: ""
  property bool repairing: false
  readonly property int lineLimit: 4 * 1024 * 1024
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

  function receiveChunk(chunk) {
    var text = root.pending + chunk
    var start = 0
    var end = text.indexOf("\n")
    while (end !== -1) {
      if (end - start <= root.lineLimit) root.receive(text.slice(start, end))
      start = end + 1
      end = text.indexOf("\n", start)
    }
    root.pending = text.slice(start)
    if (root.pending.length > root.lineLimit) {
      // A line this long is not a status. Drop it and start over.
      root.pending = ""
      socket.connected = false
    }
  }

  function receive(text) {
    if (text.length > root.lineLimit) return
    try {
      var message = JSON.parse(text)
      if (message.protocol_version !== 1) return
      var value = null
      var response = message.type === "response" && String(message.id) === root.requestId
      if (response) {
        // A late snapshot must not replace an event already received.
        if (root.eventSinceRequest) return
        // Busy snapshots are retried without throwing away the last layout.
        if (message.error) { retrySubscribe.restart(); return }
        value = message.result
      } else if (message.type === "event" && message.event === "status") value = message.data
      // The watchdog keeps running until a status validates, so an invalid
      // reply ends in a reconnect instead of a stale layout.
      if (!value || value.schema_version !== 1 || !Array.isArray(value.monitors)) return
      responseTimeout.stop()
      if (message.type === "event") {
        root.eventSinceRequest = true
        retrySubscribe.stop()
      }
      root.document = value
      root.ready = true
      // Chunks are decoded one at a time, so a character split between two
      // reads arrives as U+FFFD. Ask once for a fresh snapshot to repair it.
      if (text.indexOf("\ufffd") !== -1 && !(response && root.repairing)) {
        root.repairing = true
        retrySubscribe.restart()
      } else if (response) root.repairing = false
    } catch (_) { /* Ignore malformed messages; a later status repairs the view. */ }
  }

  Socket {
    id: socket
    path: root.socketPath
    connected: root.runtimeDir !== ""
    onConnectedChanged: {
      root.pending = ""
      root.repairing = false
      if (connected) root.subscribe()
      else { root.ready = false; responseTimeout.stop(); retrySubscribe.stop() }
    }
    // An empty marker hands over each read as it arrives.
    parser: SplitParser { splitMarker: ""; onRead: function(data) { root.receiveChunk(data) } }
    onError: function(error) {
      // Quickshell is still delivering the socket error. Defer teardown until
      // that callback returns, as the panel and preview guard do.
      Qt.callLater(function() { socket.connected = false })
    }
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
