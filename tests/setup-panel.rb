require 'minitest/autorun'
require 'tmpdir'
require_relative '../scripts/setup-panel'

class PanelSetupTest < Minitest::Test
  class Host
    attr_reader :calls
    def initialize(panel: nil, decline: false, fail: false, route_after: 0)
      @panel, @decline, @fail, @route_after, @calls = panel, decline, fail, route_after, []
    end
    def plugins = @panel ? [@panel] : []
    def run(*args)
      @calls << args
      raise 'Canceled' if @fail
      @panel = {'id'=>PanelSetup::ID,'enabled'=>!@decline} if args[0]=='add'
      @panel['enabled']=true if args[0]=='enable'
    end
    def open_workspace(origin)
      @calls << [:open, origin]
      @route_after -= 1
      @route_after < 0
    end
    def wait = @calls << [:wait]
    def open_panel = @calls << [:fallback]
  end
  def panel(enabled) = {'id'=>PanelSetup::ID,'enabled'=>enabled}

  def test_first_install_uses_native_questions_and_opens_workspace_setup
    host=Host.new
    assert_equal :opened, PanelSetup.run(host,'install','{"screen":"DP-1"}')
    assert_equal [['add',PanelSetup::URL],[:open,'{"screen":"DP-1"}']], host.calls
  end
  def test_disabled_panel_is_enabled_without_reinstallation
    host=Host.new(panel:panel(false))
    PanelSetup.run(host,'enable','{}')
    assert_equal ['enable',PanelSetup::ID],host.calls.first
  end
  def test_declined_enablement_does_not_open_or_install_a_daemon
    host=Host.new(decline:true)
    assert_equal :disabled,PanelSetup.run(host,'install','{}')
    assert_equal [['add',PanelSetup::URL]],host.calls
  end
  def test_canceled_install_stops_before_opening
    host=Host.new(fail:true)
    assert_raises(RuntimeError) { PanelSetup.run(host,'install','{}') }
    assert_equal [['add',PanelSetup::URL]],host.calls
  end
  def test_reload_is_retried_and_old_panel_gets_normal_setup
    host=Host.new(panel:panel(true),route_after:50)
    assert_equal :opened,PanelSetup.run(host,'update','{}')
    assert_equal 12,host.calls.count { |call| call.first==:open }
    assert_equal [:fallback],host.calls.last
  end
  def test_racing_install_does_not_overwrite_existing_plugin
    host=Host.new(panel:panel(true))
    PanelSetup.run(host,'install','{}')
    assert_equal [[:open,'{}']],host.calls
  end
  def with_fake_omarchy(script)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'omarchy')
      File.write(path, "#!/bin/sh\n#{script}\n")
      File.chmod(0o755, path)
      original = ENV['PATH']
      ENV['PATH'] = "#{dir}:#{original}"
      yield
    ensure
      ENV['PATH'] = original
    end
  end
  def test_plugin_list_is_read_up_to_its_limit_and_then_stopped
    with_fake_omarchy('head -c 2000000 /dev/zero | tr "\\0" x; sleep 4') do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      error = assert_raises(RuntimeError) { PanelSetup::Omarchy.new.plugins }
      assert_match(/Could not check installed panels/, error.message)
      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2,
        'the oversized plugin list was read to the end instead of stopped at the limit'
    end
  end
  def test_plugin_list_within_the_limit_is_parsed
    with_fake_omarchy(%q(printf '[{"id":"crmne.hyprmoncfg","enabled":true}]')) do
      assert_equal [{'id'=>PanelSetup::ID,'enabled'=>true}], PanelSetup::Omarchy.new.plugins
    end
  end
  def test_invalid_input_never_runs_commands
    host=Host.new
    assert_raises(RuntimeError) { PanelSetup.run(host,'remove','{}') }
    assert_raises(JSON::ParserError) { PanelSetup.run(host,'install','invalid') }
    assert_raises(RuntimeError) { PanelSetup.run(host,'install','[]') }
    assert_empty host.calls
  end
end
