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
# TypingTestSession::FRUSTRATION_THRESHOLD to cancel the test, and every
# keystroke here forces a real text-view layout pass (for the caret position)
# on top of the Ruby call overhead, both measured against real wall-clock
# time (Process.clock_gettime) in TextView#record_keystroke and
# TypingTestSession#check_frustration. Under headless/software rendering, the
# *first* handful of those passes pay a one-time cost — Pango has to shape the
# monospace font and size the layout caches it then reuses — that can run
# into the hundreds of milliseconds, well under the rate the threshold needs;
# most passes after that, once the caches are warm, are fast enough.
# `warm_up_text_view_layout` below pays that one-time cost on throwaway
# keystrokes before the timed test (and its frustration window) starts, so
# every keystroke that counts is past the cold part — but the mash still has
# to win a real race against whatever else is making this host slow at the
# moment it runs (other processes contending for the same CPU chief among
# them), and a race against real wall-clock time cannot be made to always
# win from inside the thing being raced. A 9-usable-run sample on a heavily
# loaded shared host this round (out of an attempted 20 — the rest lost to
# host-level D-Bus collisions, not to anything this fix changes) still hit
# the exact failure this file's history says it fixed (commit "test: make
# the frustration-cancel mash deterministic") on 4 of those 9 runs — see
# .reports/test-parity.md for the numbers. That commit's claim was false then
# and the warm-up here has not been shown to make it true: it narrows the
# window (the first few keystrokes are no longer the slow ones), it does not
# close it. The loop still checks
# after every key and stops as soon as the test cancels, rather than firing a
# fixed count and hoping it was enough, which is the only part of the old
# claim this file can actually stand behind.
MAX_MASHED_KEYS = 300

# Repeatedly committing and then discarding keystrokes exercises exactly the
# same caret/scroll layout code path (TextView#update_caret_position,
# #update_scroll_position) that the timed mash below depends on being fast,
# without affecting anything the lifecycle checks afterwards: `reset` clears
# the typed text, the original text and `running` right back to how `ready`
# left them.
def warm_up_text_view_layout(text_view)
  original_text = text_view.original_text

  text_view.accepts_input = true
  20.times { text_view.input_context.signal_emit("commit", "~") }
  text_view.reset
  text_view.original_text = original_text
end

SHOTS = File.expand_path("../tmp/shots", __dir__)

application = Keypunch::Application.new

GtkDriver.drive(application, shots: SHOTS) do |driver, app|
  window = -> { app.main_window }

  driver.window { window.call.window }

  driver.step("warm up the text view's layout before timing anything") do
    warm_up_text_view_layout(window.call.text_view)
  end

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
