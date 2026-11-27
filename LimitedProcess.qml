import QtQuick
import Quickshell.Io

// A process whose output is collected as it streams, up to `limit`
// characters. StdioCollector keeps everything until the process ends, so a
// command that prints too much is stopped as soon as it passes the limit and
// counts as failed (`overflowed`), with no text.
Process {
  id: root

  property int limit: 1048576
  property string text: ""
  property bool overflowed: false
  signal done(int exitCode, string text)

  function start() {
    root.text = ""
    root.overflowed = false
    root.running = true
  }

  // An empty marker hands over each read as it arrives.
  stdout: SplitParser {
    splitMarker: ""
    onRead: function(data) {
      if (root.overflowed) return
      if (root.text.length + data.length > root.limit) {
        root.overflowed = true
        root.text = ""
        root.running = false
        return
      }
      root.text += data
    }
  }

  onExited: function(exitCode) {
    root.done(root.overflowed ? -1 : exitCode, root.overflowed ? "" : root.text)
  }
}
