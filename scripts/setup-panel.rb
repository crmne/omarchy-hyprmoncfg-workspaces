#!/usr/bin/env ruby
require 'json'
require 'open3'

module PanelSetup
  ID = 'crmne.hyprmoncfg'
  URL = 'https://github.com/crmne/omarchy-hyprmoncfg'

  class Omarchy
    def plugins
      out, _, result = Open3.capture3('timeout', '5s', 'omarchy', 'plugin', 'list', '--json')
      raise 'Could not check installed panels. Reopen the picker and try again.' unless result.success? && out.bytesize < 1_048_576
      entries = JSON.parse(out)
      raise 'Invalid plugin list.' unless entries.is_a?(Array)
      entries
    end

    def run(*args)
      raise 'Panel setup did not finish. Reopen the picker to try again.' unless system('omarchy', 'plugin', *args)
    end

    def open_workspace(origin)
      out, _, result = Open3.capture3('omarchy-shell', 'crmne.hyprmoncfg.editor', 'workspaces', origin)
      result.success? && out.strip == 'ok'
    end

    def open_panel
      out, _, result = Open3.capture3('omarchy-shell', 'shell', 'summon', ID, '{}')
      result.success? && out.strip == 'ok'
    end

    def wait = sleep(0.25)
  end

  def self.run(host, action, origin)
    raise 'Unknown panel setup action.' unless %w[install enable update].include?(action)
    raise 'Invalid picker location.' unless origin.bytesize <= 4096 && JSON.parse(origin).is_a?(Hash)
    panel = host.plugins.find { |entry| entry['id'] == ID }
    case action
    when 'install'
      # Re-check in case another bar installed it while this prompt was open.
      if panel
        host.run('enable', ID) unless panel['enabled']
      else
        # Keep Omarchy's trust, enablement and placement questions.
        host.run('add', URL)
      end
    when 'enable', 'update'
      raise 'Install the hyprmoncfg panel first.' unless panel
      host.run(action, ID)
    end
    panel = host.plugins.find { |entry| entry['id'] == ID }
    # Respect declining enablement in Omarchy's installer.
    return :disabled unless panel && panel['enabled']

    # Enabling reloads the bar, so the editor route may take a moment to arrive.
    12.times do
      return :opened if host.open_workspace(origin)
      host.wait
    end
    # An older panel can still show its normal daemon installer.
    raise 'Panel installed, but could not open. Reopen it from the bar.' unless host.open_panel
    :opened
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    result = PanelSetup.run(PanelSetup::Omarchy.new, ARGV.fetch(0, ''), ARGV.fetch(1, '{}'))
    puts 'Panel installed. Choose Enable hyprmoncfg panel in the picker to continue.' if result == :disabled
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
