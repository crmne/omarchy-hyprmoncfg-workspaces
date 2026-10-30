#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'open3'
require 'socket'
require 'tmpdir'

root = File.expand_path('..', __dir__)
cache = File.join(Dir.home, '.cache', 'hmw-reconnect')
FileUtils.mkdir_p(cache)
Dir.mktmpdir('r-', cache) do |stage|
  runtime = File.join(stage, 'rt')
  FileUtils.mkdir_p(runtime, mode: 0700)
  FileUtils.cp(File.join(root, 'WorkspaceService.qml'), stage)
  File.write(File.join(stage, 'shell.qml'), <<~QML)
    import QtQuick
    import Quickshell
    ShellRoot {
      WorkspaceService {
        id: service
        property int snapshots: 0
        property int disconnects: 0
        onDocumentChanged: if (document.schema_version === 1) snapshots++
        onConnectedChanged: if (!connected && snapshots > 0) disconnects++
      }
      Timer {
        interval: 20; repeat: true; running: true
        onTriggered: {
          if (service.snapshots >= 10 && service.disconnects >= 10 && !service.ready) {
            console.log("RECONNECT_PASS"); Qt.quit()
          }
        }
      }
    }
  QML
  server = UNIXServer.new(File.join(runtime, 'hyprmoncfgd.sock'))
  stop = false
  peer = Thread.new do
    until stop
      next unless IO.select([server], nil, nil, 0.1)
      socket = server.accept
      begin
        request = JSON.parse(socket.gets)
        raise 'Wrong method' unless request['method'] == 'subscribe'
        socket.puts(JSON.generate(type: 'response', protocol_version: 1, id: request['id'],
          result: {schema_version: 1, monitors: [], workspace_plan: []}))
        sleep 0.04
      ensure
        socket.close
      end
    end
  end
  begin
    output, result = Open3.capture2e(
      {'XDG_RUNTIME_DIR' => runtime, 'QT_QPA_PLATFORM' => 'offscreen',
       'QT_QPA_PLATFORMTHEME' => 'basic', 'QT_QUICK_BACKEND' => 'software',
       'QS_DISABLE_CRASH_HANDLER' => '1'},
      'timeout', '30s', 'quickshell', '-p', stage, '--no-color', rlimit_core: 0)
    unless result.success? && output.include?('RECONNECT_PASS') && output.scan('PeerClosedError').length >= 10
      warn output
      abort 'Workspace reconnect test failed'
    end
    puts 'PASS: production service survives 10 peer closures and resubscribes after each one'
  ensure
    stop = true
    peer.join(2) || raise('Socket peer did not stop')
    server.close
  end
end
Dir.rmdir(cache) if Dir.empty?(cache)
