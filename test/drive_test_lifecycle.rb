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

# Each mistake needs more than ten per second of
# TypingTestSession::FRUSTRATION_THRESHOLD to cancel the test, but every
# keystroke here forces a real text-view layout pass (for the caret position)
# on top of the Ruby call overhead, and under headless/software rendering
# that single pass alone can run into the hundreds of milliseconds — slower,
# some runs, than the rate the threshold needs. There is no way to mash fast
# enough to guarantee hitting the window on every run, so this keeps mashing,
# checking after every key, until the test actually cancels or a generous cap
# is reached, rather than firing a fixed count and hoping it was enough.
MAX_MASHED_KEYS = 300

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
    MAX_MASHED_KEYS.times do
      break unless window.call.running?

      window.call.text_view.input_context.signal_emit("commit", "~")
    end
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

  driver.step("focus the text view, then take focus away from the window entirely") do
    window.call.focus_text_view
    window.call.window.set_focus(nil)
  end

  # WindowFocus debounces for WindowFocus::UNFOCUSED_TIMEOUT_MILLIS (2000ms)
  # before blurring, so a handful of empty ticks have to pass first.
  4.times { |n| driver.step("waiting for the unfocus timeout (#{n})") {} }

  driver.step("the unfocused affordance showed up") do
    driver.check("the enable-entry button replaced the prompt") do
      window.call.bottom_stack.visible_child == window.call.focus_button
    end
    driver.check("the text view is blurred") { window.call.text_view.root.css_classes.include?("unfocused") }
    driver.shot("24-unfocused")
  end

  driver.step("click the enable-entry button") { window.call.focus_button.signal_emit("clicked") }

  driver.step("focus came back") do
    driver.check("the text view lost the blur") { !window.call.text_view.root.css_classes.include?("unfocused") }
    driver.check("the prompt is back") { window.call.bottom_stack.visible_child == window.call.just_start_typing }
    driver.shot("25-refocused")
  end
end
