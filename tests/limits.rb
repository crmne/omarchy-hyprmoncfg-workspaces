#!/usr/bin/env ruby
# The production WorkspaceService in an offscreen Quickshell against a fake
# daemon: an endless line is cut off at 4 MiB, an invalid reply leaves the
# watchdog running until it reconnects, and a character split between two
# reads is repaired.
require 'fileutils'
require 'json'
require 'open3'
require 'socket'
require 'tmpdir'

root = File.expand_path('..', __dir__)
cache = File.join(Dir.home, '.cache', 'hmw-limits')
FileUtils.mkdir_p(cache)
status = ->(id, extra = {}) { JSON.generate({type: 'response', protocol_version: 1, id: id,
  result: {schema_version: 1, monitors: [], workspace_plan: []}.merge(extra)}) + "\n" }

Dir.mktmpdir('l-', cache) do |stage|
  runtime = File.join(stage, 'rt')
  FileUtils.mkdir_p(runtime, mode: 0o700)
  %w[WorkspaceService.qml].each { |name| FileUtils.cp(File.join(root, name), stage) }
  File.write(File.join(stage, 'shell.qml'), <<~QML)
    import QtQuick
    import Quickshell
    ShellRoot {
      WorkspaceService { id: service }
      Timer {
        interval: 20; repeat: true; running: true
        property string last: ""
        onTriggered: {
          var line = service.connected + " " + service.ready + " " + JSON.stringify(service.document.label || "")
          if (line !== last) { console.log("STATE", line); last = line }
        }
      }
    }
  QML
  server = UNIXServer.new(File.join(runtime, 'hyprmoncfgd.sock'))
  log = Queue.new
  peer = Thread.new do
    # 1: a valid status, then a line that never ends.
    socket = server.accept
    request = JSON.parse(socket.gets)
    socket.write(status.(request['id'], label: 'first'))
    sent = 0
    begin
      while sent < 64 * 1024 * 1024
        socket.write('x' * 65_536)
        sent += 65_536
      end
      log << "flood not cut off after #{sent} bytes"
    rescue Errno::EPIPE, Errno::ECONNRESET
      log << "flood cut off after #{sent / 1024 / 1024} MiB"
    end
    socket.close rescue nil
    # 2: a reply with an invalid schema, then silence.
    socket = server.accept
    request = JSON.parse(socket.gets)
    socket.write(JSON.generate({type: 'response', protocol_version: 1, id: request['id'],
      result: {schema_version: 2}}) + "\n")
    started = Time.now
    IO.select([socket], nil, nil, 10)
    log << (socket.read_nonblock(1, exception: false).nil? ? "invalid reply closed after #{(Time.now - started).round}s" : 'invalid reply kept open')
    socket.close rescue nil
    # 3: a status whose label is split inside a character, then a clean one.
    socket = server.accept
    request = JSON.parse(socket.gets)
    bytes = status.(request['id'], label: "Grüße").b
    cut = bytes.index("ü".b) + 1
    socket.write(bytes[0, cut]); socket.flush; sleep 0.3
    socket.write(bytes[cut..]); socket.flush
    request = JSON.parse(socket.gets.to_s)
    log << 'repair requested'
    socket.write(status.(request['id'], label: "Grüße"))
    sleep 1
    socket.close
  rescue StandardError => e
    log << "peer stopped: #{e.message}"
  end
  output, = Open3.capture2e(
    {'XDG_RUNTIME_DIR' => runtime, 'QT_QPA_PLATFORM' => 'offscreen', 'QT_QPA_PLATFORMTHEME' => 'basic',
     'QT_QUICK_BACKEND' => 'software', 'QS_DISABLE_CRASH_HANDLER' => '1', 'WAYLAND_DISPLAY' => ''},
    'timeout', '25s', 'quickshell', '-p', stage, '--no-color', rlimit_core: 0)
  peer.join(5)
  events = []
  events << log.pop until log.empty?
  checks = {
    'the endless line is cut off near 4 MiB' => events.any? { |e| e =~ /flood cut off after ([0-9]+) MiB/ && $1.to_i < 16 },
    'an invalid reply ends in a reconnect' => events.any? { |e| e =~ /invalid reply closed after ([0-9]+)s/ && $1.to_i <= 8 },
    'a split character is repaired' => events.include?('repair requested') && output.include?('STATE true true "Grüße"')
  }
  failed = checks.reject { |_, ok| ok }.keys
  unless failed.empty?
    warn output, events.inspect
    abort "Limits test failed: #{failed.join(', ')}"
  end
  puts "PASS: #{checks.keys.join('; ')}"
ensure
  server&.close
end
Dir.rmdir(cache) if Dir.exist?(cache) && Dir.empty?(cache)
