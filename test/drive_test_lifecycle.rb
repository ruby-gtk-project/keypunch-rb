# frozen_string_literal: true

# Drives the parts of the test lifecycle the main-window run does not reach:
# the countdown of a timed test, the frustration cancel, and the narrow
# breakpoint.
#
# Run it with:
#
#   nix develop --command xvfb-run -a ruby test/drive_test_lifecycle.rb

require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "keypunch"
require_relative "gtk_driver"

# Comfortably more than the twenty-two mistakes in 2.2 seconds that
# TypingTestSession::FRUSTRATION_THRESHOLD works out to.
MASHED_KEYS = 40

SHOTS = File.expand_path("../tmp/shots", __dir__)

application = Keypunch::Application.new

GtkDriver.drive(application, shots: SHOTS) do |driver, app|
  window = -> { app.main_window }

  driver.window { window.call.window }

  driver.step("a timed test is configured") do
    app.settings["session-type"] = "Simple"
    app.settings["session-duration"] = "Sec15"
  end

  driver.step("start typing") do
    window.call.focus_text_view
    window.call.text_view.input_context.signal_emit("commit", window.call.text_view.original_text[0])
  end

  driver.step("the countdown is running") do
    driver.check("a test is in progress") { window.call.running? }
    driver.check("the status is a number of seconds") { window.call.status_label.label.match?(/\A\d+\z/) }
    driver.check("the window hides its controls") { window.call.window.css_classes.include?("hide-controls") }
    driver.shot("20-timed-running")
  end

  driver.step("mash the keyboard") do
    MASHED_KEYS.times { window.call.text_view.input_context.signal_emit("commit", "~") }
  end

  driver.step("the test was cancelled") do
    driver.check("the cancelled page is showing") do
      window.call.main_stack.visible_child_name == "test-cancelled"
    end
    driver.check("no test is in progress any more") { !window.call.running? }
  end

  # The crossfade to the cancelled page has to finish before the offscreen
  # renderer has a node to hand back.
  driver.step("look at the cancelled page") do
    driver.shot("21-cancelled")
  end

  driver.step("continue back to ready") do
    window.call.frustration_continue_button.signal_emit("clicked")
  end

  driver.step("narrow the window") do
    window.call.window.set_default_size(400, 600)
  end

  driver.step("the narrow layout took over") do
    driver.check("the status moved below the header bar") do
      window.call.test_view.layout_name == "status-bottom"
    end
    driver.check("the status label is start-aligned") { window.call.status_label.xalign.zero? }
    driver.shot("22-narrow")
  end

  driver.step("widen it again") do
    window.call.window.set_default_size(900, 600)
  end

  driver.step("the wide layout came back") do
    driver.check("the status is back in the header bar") do
      window.call.test_view.layout_name == "status-top"
    end
    driver.shot("23-wide")
  end
end
