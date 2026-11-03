# frozen_string_literal: true

require "adwaita"

require_relative "custom_text_dialog"
require_relative "settings"
require_relative "text_generation"
require_relative "text_language_dialog"
require_relative "text_utils"
require_relative "translations"
require_relative "typing_test_utils"

# TypingTestSession is the lifecycle of a typing test: getting ready, starting
# on the first keystroke, counting down or counting words, finishing, being
# cancelled, and showing the results.
#
# Ported from upstream's src/widgets/window/typing_test.rs, and mixed into
# Window. Upstream reacts to the text view's `notify::running` and
# `typed-text-changed` signals; the Ruby text view has no GObject signals of
# its own, so Window hands it `test_view_running_changed` and
# `typed_text_changed` as callbacks and they are the same two entry points.
#
module TypingTestSession
  include Translations::Helpers
  include TypingTestUtils

  # The lower this is, the more sensitive Keypunch is to "frustration" (random
  # key mashing). If enough frustration is detected, the test will be
  # cancelled, and a helpful message will be displayed.
  FRUSTRATION_THRESHOLD = 2.2

  TIMER_TICK_MILLIS = 100

  # How long the stop button stays invisible after a test starts, matching the
  # crossfade of the status stack.
  STOP_BUTTON_FADE_MILLIS = 200

  RESULTS_FOCUS_DELAY_MILLIS = 500
  FRUSTRATION_FOCUS_DELAY_MILLIS = 1000

  # The accuracy a test has to beat before its speed counts as a personal best.
  PERSONAL_BEST_MIN_ACCURACY = 0.9

  # Translators: This is shown as a warning by GNOME Shell before logging out
  # or shutting off the system in the middle of a typing test
  INHIBIT_REASON = N_("Ongoing typing test")

  def setup_test_config
    settings.bind_dropdown_selected(test_type_dropdown, "session-type", Settings::SESSION_TYPE_VALUES)
    settings.bind_dropdown_selected(duration_dropdown, "session-duration", Settings::SESSION_DURATION_VALUES)

    %w[session-type text-language custom-text].each do |key|
      settings.connect_changed(key) do
        refresh_original_text
        focus_text_view
      end
    end

    duration_dropdown.signal_connect("notify::selected-item") do
      update_time
      focus_text_view
    end

    custom_button.signal_connect("clicked") { show_custom_text_dialog }
  end

  # Hides the pointer and the header bar controls while the user types, and
  # brings them back as soon as the pointer moves or is clicked.
  def setup_ui_hiding
    @show_cursor = true

    motion_controller.signal_connect("motion") { pointer_moved }
    window_click_gesture.signal_connect("released") { pointer_clicked }

    window.add_controller(motion_controller)
    window.add_controller(window_click_gesture)
  end

  # The text view starts a test by turning its `running` on.
  def test_view_running_changed(view)
    if view.running?
      start
    end
  end

  def typed_text_changed(view)
    hide_controls_while_typing

    @current_test.then do |test|
      if test
        check_finished(view)
        extend_original_text(test.config)
        update_word_counter(view, test.config)
        check_frustration(view)
      end
    end
  end

  def ready
    @current_test = nil
    text_view.running = false
    text_view.accepts_input = true

    main_stack.visible_child_name = "test"
    status_stack.visible_child_name = "ready"
    bottom_stack.visible_child = just_start_typing
    menu_button.visible = true
    stop_button.visible = false

    text_view.reset
    focus_text_view

    refresh_original_text
    update_time

    text_language_action.enabled = true
    cancel_test_action.enabled = false
    window.remove_css_class("hide-controls")

    discord_rpc.set_activity(TestConfig.from_settings(settings), PresenceState::READY)

    inhibitor.end_existing
  end

  def start
    config = TestConfig.from_settings(settings)

    @current_test = TypingTest.new(config)
    main_stack.visible_child_name = "test"
    status_stack.visible_child_name = "running"
    hide_cursor
    bottom_stack.visible_child = bottom_stack_empty

    reveal_stop_button

    if config.generated?
      start_timer(config)
    end

    text_language_action.enabled = false
    cancel_test_action.enabled = true
    window.add_css_class("hide-controls")

    discord_rpc.set_activity(config, PresenceState::TYPING)

    inhibitor.inhibit(_(INHIBIT_REASON))
  end

  def finish
    @current_test.then do |test|
      if test
        end_test
        show_results_view(test, Process.clock_gettime(Process::CLOCK_MONOTONIC))
        discord_rpc.set_activity(test.config, PresenceState::RESULTS)
      end
    end
  end

  # Cancels a test that has turned into key mashing, and says so.
  def frustration_relief
    if running?
      end_test
      main_stack.visible_child_name = "test-cancelled"

      # Avoid the continue button being activated from a keypress immediately
      window.set_focus(nil)

      GLib::Timeout.add(FRUSTRATION_FOCUS_DELAY_MILLIS) do
        frustration_continue_button.grab_focus
        false
      end
    end
  end

  def end_test
    @current_test = nil
    text_view.running = false
    text_view.accepts_input = false

    text_language_action.enabled = false
    cancel_test_action.enabled = false

    inhibitor.end_existing
  end

  def hide_cursor
    @show_cursor = false
    @cursor_hidden_timestamp = pointer.timestamp
    window.set_cursor_from_name("none")
  end

  def show_cursor
    @show_cursor = true
    window.set_cursor_from_name("default")
  end

  # Regenerates the text to type from the current configuration. A running
  # test keeps the text it started with.
  def refresh_original_text
    if !running?
      config = TestConfig.from_settings(settings)

      secondary_config_stack.visible_child = secondary_config_widget(config)
      text_view.original_text = original_text_for(config)

      discord_rpc.set_activity(config, PresenceState::READY)
    end
  end

  def update_time
    discord_rpc.set_activity(TestConfig.from_settings(settings), PresenceState::READY)
  end

  def show_text_language_dialog
    if !running? && window.visible_dialog.nil?
      TextLanguageDialog.new(settings).build.tap do |dialog|
        dialog.signal_connect("closed") { focus_text_view }
        dialog.present(window)
      end
    end
  end

  def show_custom_text_dialog(initial_override = nil)
    if !running? && window.visible_dialog.nil?
      build_custom_text_dialog(initial_override).tap do |dialog|
        dialog.signal_connect("closed") { focus_text_view }
        dialog.present(window)
      end
    end
  end

  # Appends another chunk of generated text, so a timed test never runs out.
  def extend_original_text(config)
    if config.generated? && text_view.typed_grapheme_count > extension_threshold
      text_view.push_original_text(generated_text(config))
    end
  end

  def start_timer(config)
    seconds = TestDuration.seconds(config.duration)
    update_timer(seconds + 1)

    GLib::Timeout.add(TIMER_TICK_MILLIS) { tick(seconds) }
  end

  def show_results_view(test, finish_instant)
    summary = summary_for(test, finish_instant)

    results_view.set_summary(summary)
    results_view.show_personal_best = record_personal_best(summary)

    main_stack.visible_child_name = "results"

    window.set_focus(nil)

    GLib::Timeout.add(RESULTS_FOCUS_DELAY_MILLIS) do
      results_continue_button.grab_focus
      false
    end

    discord_rpc.set_stats(summary.wpm, summary.accuracy)
  end

  # Replaces the stored best for this exact configuration with a new one.
  # Upstream's `add_personal_best`.
  def self.add_personal_best(stored, record)
    test_type, duration, language, = record

    stored.reject do |stored_type, stored_duration, stored_language, _wpm|
      stored_type == test_type && stored_duration == duration && stored_language == language
    end + [record]
  end

  # Memoized controllers

  def motion_controller = @motion_controller ||= Gtk::EventControllerMotion.new

  def window_click_gesture = @window_click_gesture ||= Gtk::GestureClick.new

  private

    def discord_rpc = @discord_rpc

    def pointer = window.display.default_seat.pointer

    def pointer_moved
      if !@show_cursor && pointer.timestamp > @cursor_hidden_timestamp
        restore_controls
      end
    end

    def pointer_clicked
      if !@show_cursor
        restore_controls
      end
    end

    def restore_controls
      show_cursor

      if running?
        window.remove_css_class("hide-controls")
      end
    end

    def hide_controls_while_typing
      if @show_cursor && running?
        window.add_css_class("hide-controls")
        hide_cursor
      end
    end

    def reveal_stop_button
      # Ugly hack to stop the stop button from "flashing" when starting a test:
      # make it visible with 0 opacity, and set the opacity to 1 after the
      # 200ms crossfade effect has finished
      stop_button.opacity = 0.0
      stop_button.visible = true

      GLib::Timeout.add(STOP_BUTTON_FADE_MILLIS) do
        if running?
          menu_button.visible = false
          stop_button.opacity = 1.0
        end

        false
      end
    end

    # A test is over once everything has been typed and the last grapheme is
    # not still being composed.
    def check_finished(view)
      finished = view.typed_grapheme_count >= view.original_grapheme_count &&
        view.last_grapheme_state != TextUtils::UNFINISHED

      if finished
        finish
      end
    end

    def extension_threshold
      [text_view.original_grapheme_count - (TextGeneration::CHUNK_GRAPHEME_COUNT / 2), 0].max
    end

    def update_word_counter(view, config)
      if config.finite?
        current, total = view.progress

        # Translators: The format of the word counter. The `{}` blocks will be
        # replaced with the number of the word being typed and the number of
        # words in the text. Do not translate them. The `⁄` sign is a fraction
        # slash, not the ASCII slash it resembles; if your language doesn't
        # use something completely different, you should probably copy and
        # paste it from the original string.
        status_label.label = fmt(_("{} ⁄ {}"), current, total)
      end
    end

    # Counts the mistakes made in the last FRUSTRATION_THRESHOLD seconds, and
    # cancels the test once there are more than ten per second of it.
    def check_frustration(view)
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      score = view.keystrokes
        .reverse_each
        .take_while { |timestamp, _correct| now - timestamp <= FRUSTRATION_THRESHOLD }
        .count { |_timestamp, correct| !correct }

      if score > FRUSTRATION_THRESHOLD * 10
        frustration_relief
      end
    end

    def secondary_config_widget(config)
      if config.finite?
        custom_button
      else
        duration_dropdown
      end
    end

    def original_text_for(config)
      if config.finite?
        TextUtils.process_custom_text(settings["custom-text"])
      else
        generated_text(config)
      end
    end

    def generated_text(config)
      if config.difficulty == GeneratedTestDifficulty::ADVANCED
        TextGeneration.advanced(config.language)
      else
        TextGeneration.simple(config.language)
      end
    end

    def build_custom_text_dialog(initial_override)
      CustomTextDialog.new(
        settings,
        initial_override: initial_override,
        on_discard:       ->(discarded) { show_discard_toast(discarded) },
      ).build
    end

    def show_discard_toast(discarded)
      Adwaita::Toast.new(_("Changes discarded")).tap do |toast|
        toast.button_label = _("Restore")
        toast.signal_connect("button-clicked") { show_custom_text_dialog(discarded) }

        toast_overlay.add_toast(toast)
      end
    end

    def tick(seconds)
      @current_test.then do |test|
        if test.nil?
          false
        else
          continue_timer(test, seconds)
        end
      end
    end

    def continue_timer(test, seconds)
      remaining = seconds - test.elapsed

      if remaining.positive?
        update_timer(remaining.floor + 1)
        true
      else
        finish
        false
      end
    end

    def update_timer(seconds)
      status_label.label = timer_text(seconds)
    end

    def timer_text(seconds)
      minutes = seconds / 60
      rest = seconds % 60

      if seconds >= 60 && rest < 10
        # add trailing zero for second values below 10
        fmt(timer_format, minutes, "0#{rest}")
      elsif seconds >= 60
        fmt(timer_format, minutes, rest)
      else
        seconds.to_s
      end
    end

    def timer_format
      # Translators: The format of the timer. The first `{}` block will be
      # replaced with the minutes passed, and the second one will be replaced
      # with the seconds passed. Do not translate the `{}` blocks. Note that
      # the `∶` sign is a special Unicode character; if your language doesn't
      # use something completely different, you should probably copy and paste
      # it from the original string.
      _("{}∶{}")
    end

    def summary_for(test, finish_instant)
      TestSummary.build(
        test:        test,
        end_instant: finish_instant,
        original:    summary_original_text(test.config),
        typed:       text_view.typed_text,
        keystrokes:  text_view.keystrokes,
      )
    end

    def summary_original_text(config)
      if config.finite?
        TextUtils.process_custom_text(text_view.original_text)
      else
        text_view.original_text
      end
    end

    # Stores the summary's speed as the personal best for its configuration,
    # if it beats the one on record. Returns whether it did.
    def record_personal_best(summary)
      if summary.config.generated? && personal_best?(summary)
        settings["personal-best"] = TypingTestSession.add_personal_best(
          settings["personal-best"],
          personal_best_record(summary),
        )
        true
      else
        false
      end
    end

    def personal_best?(summary)
      stored = stored_personal_best(summary.config)

      summary.accuracy > PERSONAL_BEST_MIN_ACCURACY &&
        (stored.nil? || summary.wpm.floor > stored)
    end

    def stored_personal_best(config)
      settings["personal-best"]
        .find do |test_type, duration, language, _wpm|
          test_type == config.difficulty &&
            duration == config.duration &&
            language == config.language.code
        end
        &.last
    end

    def personal_best_record(summary)
      [
        summary.config.difficulty,
        summary.config.duration,
        summary.config.language.code,
        summary.wpm.floor,
      ]
    end
end
