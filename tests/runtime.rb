#!/usr/bin/env ruby
require 'fileutils'
require 'open3'
require 'tmpdir'
require 'json'

root = File.expand_path('..', __dir__)
shell = File.join(ENV.fetch('OMARCHY_PATH', '/usr/share/omarchy'), 'shell')
abort 'Run in an Omarchy/Hyprland session' unless ENV['HYPRLAND_INSTANCE_SIGNATURE'] && File.directory?(shell)
cache = File.join(Dir.home, '.cache', 'hyprmoncfg-workspace-tests')
FileUtils.mkdir_p(cache)
Dir.mktmpdir('runtime-', cache) do |stage|
  %w[Ui Commons].each { |dir| File.symlink(File.join(shell, dir), File.join(stage, dir)) }
  Dir.glob(File.join(root, '*.qml')).each { |path| FileUtils.cp(path, stage) }
  FileUtils.cp(File.join(root, 'WorkspaceModel.js'), stage)
  FileUtils.cp_r(File.join(root, 'i18n'), stage)
  FileUtils.cp(File.join(__dir__, 'runtime.qml'), File.join(stage, 'shell.qml'))
  output, result = Open3.capture2e(
    { 'QT_QPA_PLATFORM' => 'wayland', 'QT_QPA_PLATFORMTHEME' => 'basic', 'QT_STYLE_OVERRIDE' => 'Fusion' },
    'timeout', '15s', 'quickshell', '-p', stage, '--no-color')
  unless result.success? && output.include?('WORKSPACES_PASS') && !output.match?(/TypeError|ReferenceError|WORKSPACES_FAIL|Failed to load|Error loading/)
    warn output
    abort 'Workspace runtime test failed'
  end
  puts 'Workspace runtime passed: actual Qt delegates, direct compositor commands, scroll, and IPC recovery'
end
Dir.rmdir(cache) if Dir.empty?(cache)
