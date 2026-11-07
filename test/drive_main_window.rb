# frozen_string_literal: true

# Drives the main window: a custom-text test from ready to results, then each
# of the three dialogs the window can open.
#
# Run it with:
#
#   nix develop --command xvfb-run -a ruby test/drive_main_window.rb

require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "keypunch"
require_relative "gtk_driver"

CUSTOM_TEXT = "hello world"
SHOTS = File.expand_path("../tmp/shots", __dir__)

application = Keypunch::Application.new

GtkDriver.drive(application, shots: SHOTS) do |driver, app|
  window = -> { app.main_window }

  driver.window { window.call.window }

  driver.step("the window comes up ready") do
    driver.check("the test page is showing") { window.call.main_stack.visible_child_name == "test" }
    driver.check("the status is the ready one") { window.call.status_stack.visible_child_name == "ready" }
    driver.check("there is text to type") { !window.call.text_view.original_text.empty? }
    driver.check("the prompt is shown") { window.call.bottom_stack.visible_child == window.call.just_start_typing }
    driver.shot("01-ready")
  end

  driver.step("switch to a short custom text") do
    app.settings["custom-text"] = CUSTOM_TEXT
    app.settings["session-type"] = "Custom"
  end

  driver.step("the custom text is loaded") do
    driver.check("the edit button replaces the duration dropdown") do
      window.call.secondary_config_stack.visible_child == window.call.custom_button
    end
    driver.check("the custom text is the text to type") do
      window.call.text_view.original_text == CUSTOM_TEXT
    end
    driver.shot("02-custom-ready")
  end

  driver.step("type the first letter") do
    window.call.focus_text_view
    window.call.text_view.input_context.signal_emit("commit", "h")
  end

  driver.step("the test is running") do
    driver.check("a test is in progress") { window.call.running? }
    driver.check("the status is the running one") { window.call.status_stack.visible_child_name == "running" }
    driver.check("the word counter is showing") { !window.call.status_label.label.empty? }
    driver.shot("03-running")
  end

  driver.step("type the rest of it") do
    CUSTOM_TEXT.chars.drop(1).each { |char| window.call.text_view.input_context.signal_emit("commit", char) }
  end

  driver.step("the results are shown") do
    driver.check("the results page is showing") { window.call.main_stack.visible_child_name == "results" }
    driver.check("no test is in progress any more") { !window.call.running? }
    driver.check("a speed was worked out") { !window.call.results_view.wpm_label.label.empty? }
    driver.check("the accuracy is a percentage") { window.call.results_view.accuracy_label.label.end_with?("%") }
    driver.check("the test type is Custom") { window.call.results_view.test_type_label.label == "Custom" }
    driver.check("a custom test reports no language") { !window.call.results_view.language_box.visible? }
    driver.shot("04-results")
  end

  driver.step("continue back to ready") do
    window.call.results_continue_button.signal_emit("clicked")
  end

  driver.step("back on the test page") do
    driver.check("the test page is showing") { window.call.main_stack.visible_child_name == "test" }
    driver.check("nothing has been typed") { window.call.text_view.typed_text.empty? }
  end

  driver.step("open the custom text dialog") do
    window.call.custom_button.signal_emit("clicked")
  end

  driver.step("the custom text dialog is up") do
    driver.check("a dialog is showing") { !window.call.window.visible_dialog.nil? }
    driver.check("it holds the stored text") { window.call.window.visible_dialog.text == CUSTOM_TEXT }
    driver.check("save is sensitive with real text") { window.call.window.visible_dialog.save_button.sensitive? }
    driver.shot("05-custom-text", window.call.window.visible_dialog)
  end

  driver.step("clear the text to nothing but whitespace") do
    window.call.window.visible_dialog.buffer.text = "   "
  end

  driver.step("whitespace-only text is rejected but keeps its placeholder hidden") do
    driver.check("the placeholder stays hidden (the field is not truly empty)") do
      !window.call.window.visible_dialog.placeholder.visible?
    end
    driver.check("save is insensitive with only whitespace") { !window.call.window.visible_dialog.save_button.sensitive? }
  end

  driver.step("clear the text completely") do
    window.call.window.visible_dialog.buffer.text = ""
  end

  driver.step("the empty state is showing") do
    driver.check("the placeholder reappears") { window.call.window.visible_dialog.placeholder.visible? }
    driver.check("save is insensitive when empty") { !window.call.window.visible_dialog.save_button.sensitive? }
    driver.shot("05a-custom-text-empty", window.call.window.visible_dialog)
  end

  driver.step("type something different instead of saving") do
    window.call.window.visible_dialog.buffer.text = "a different line"
  end

  driver.step("close without saving") { window.call.window.visible_dialog.close }

  driver.step("the unsaved change was discarded, not saved") do
    driver.check("the stored custom text is unchanged") { app.settings["custom-text"] == CUSTOM_TEXT }
    driver.shot("05b-discard-toast")
  end

  driver.step("reopen the custom text dialog") do
    window.call.custom_button.signal_emit("clicked")
  end

  driver.step("it is back to the stored text, not the discarded one") do
    driver.check("a dialog is showing") { !window.call.window.visible_dialog.nil? }
    driver.check("the discarded text was not kept") { window.call.window.visible_dialog.text == CUSTOM_TEXT }
  end

  driver.step("close it") { window.call.window.visible_dialog.close }

  driver.step("open the text language dialog") do
    window.call.window.activate_action("text-language-dialog", nil)
  end

  driver.step("the language dialog is up") do
    driver.check("a dialog is showing") { !window.call.window.visible_dialog.nil? }
    driver.shot("06-languages", window.call.window.visible_dialog)
  end

  driver.step("search for a language") do
    window.call.window.visible_dialog.search_entry.text = "franc"
  end

  driver.step("the search found something") do
    driver.check("the results page is showing") do
      window.call.window.visible_dialog.stack.visible_child_name == "search-results"
    end
    driver.shot("07-language-search", window.call.window.visible_dialog)
  end

  driver.step("search for nothing at all") do
    window.call.window.visible_dialog.search_entry.text = "zzzzzz"
  end

  driver.step("the empty state is showing") do
    driver.check("the no-results page is showing") do
      window.call.window.visible_dialog.stack.visible_child_name == "no-results"
    end
    driver.shot("08-language-empty", window.call.window.visible_dialog)
  end

  driver.step("open the add-language page") do
    window.call.window.visible_dialog.add_language_button.signal_emit("clicked")
  end

  driver.step("the add-language page is showing") do
    driver.check("the navigation moved to the add-language page") do
      window.call.window.visible_dialog.navigation_view.visible_page.tag == "add-language"
    end
    driver.shot("08a-add-language", window.call.window.visible_dialog)
  end

  driver.step("close it") { window.call.window.visible_dialog.close }

  driver.step("open the about dialog") do
    window.call.window.activate_action("about", nil)
  end

  driver.step("the about dialog is up") do
    driver.check("a dialog is showing") { !window.call.window.visible_dialog.nil? }
    driver.shot("09-about", window.call.window.visible_dialog)
  end

  driver.step("close it") { window.call.window.visible_dialog.close }

  driver.step("open the shortcuts dialog") do
    app.app.activate_action("shortcuts", nil)
  end

  driver.step("the shortcuts dialog is up") do
    driver.check("a dialog is showing") { !window.call.window.visible_dialog.nil? }
    driver.shot("10-shortcuts", window.call.window.visible_dialog)
  end

  driver.step("close it") { window.call.window.visible_dialog.close }
end
