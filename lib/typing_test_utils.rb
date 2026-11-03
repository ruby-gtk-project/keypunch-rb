# frozen_string_literal: true

require_relative "text_generation"
require_relative "text_utils"
require_relative "translations"

# TypingTestUtils holds the value objects a typing test is described and
# summarised with.
#
# Ported from upstream's src/typing_test_utils.rs (the file still calls itself
# `session_enums.rs` in its header comment). Upstream gets its enums from the
# `strum` derive macros; here each enum is a frozen array of the same nicks,
# because those nicks are what the settings store and the personal-best records
# are keyed by, and they have to keep matching.
#
module TypingTestUtils
  # Upstream's `GeneratedTestDifficulty`. The nicks match the SessionType enum
  # of the settings schema.
  module GeneratedTestDifficulty
    include Translations::Helpers

    SIMPLE = "Simple"
    ADVANCED = "Advanced"

    ALL = [SIMPLE, ADVANCED].freeze

    # The nicks read as English already, so they are their own msgids; these
    # are the markers that put them in the catalogue. Upstream reaches the
    # same two messages through `gettext` in src/widgets/results_view.rs.
    UI_STRINGS = {
      SIMPLE   => N_("Simple"),
      ADVANCED => N_("Advanced"),
    }.freeze

    module_function

    def from_settings_string(string) = ALL.find { |value| value == string }

    def ui_string(difficulty) = _(UI_STRINGS.fetch(difficulty, UI_STRINGS.fetch(SIMPLE)))
  end

  # Upstream's `TestDuration`. The nicks match the SessionDuration enum of the
  # settings schema; the seconds are the ones the test timer counts down.
  module TestDuration
    include Translations::Helpers

    SEC15 = "Sec15"
    SEC30 = "Sec30"
    MIN1 = "Min1"
    MIN5 = "Min5"
    MIN10 = "Min10"

    ALL = [SEC15, SEC30, MIN1, MIN5, MIN10].freeze
    DEFAULT = SEC15

    SECONDS = {
      SEC15 => 15,
      SEC30 => 30,
      MIN1  => 60,
      MIN5  => 5 * 60,
      MIN10 => 10 * 60,
    }.freeze

    # The English strings are the msgids too: the Discord presence wants them
    # untranslated, the dropdown wants them translated, and both come from
    # this one table.
    ENGLISH_STRINGS = {
      SEC15 => N_("15 seconds"),
      SEC30 => N_("30 seconds"),
      MIN1  => N_("1 minute"),
      MIN5  => N_("5 minutes"),
      MIN10 => N_("10 minutes"),
    }.freeze

    module_function

    def seconds(duration) = SECONDS.fetch(duration, SECONDS.fetch(DEFAULT))

    def english_string(duration) = ENGLISH_STRINGS.fetch(duration, ENGLISH_STRINGS.fetch(DEFAULT))

    # Upstream distinguishes `ui_string` (translated, for the dropdown) from
    # `english_string` (what the Discord rich presence reports, which upstream
    # keeps in English whatever the UI language is).
    def ui_string(duration) = _(english_string(duration))
  end

  # Upstream's `PresenceState`, the three states the Discord rich presence
  # reports.
  module PresenceState
    READY = :ready
    TYPING = :typing
    RESULTS = :results

    ENGLISH_STRINGS = {
      READY   => "Ready to start",
      TYPING  => "Typing",
      RESULTS => "Viewing results",
    }.freeze

    module_function

    def english_string(state) = ENGLISH_STRINGS.fetch(state)
  end

  # Upstream's `TestConfig`: either a finite test over a fixed custom text, or
  # a generated one that goes on until the clock runs out.
  class TestConfig
    FINITE = :finite
    GENERATED = :generated

    attr_reader :kind, :language, :difficulty, :duration

    def self.finite = new(FINITE)

    def self.generated(language:, difficulty:, duration:)
      new(
        GENERATED,
        language:   language,
        difficulty: difficulty,
        duration:   duration,
      )
    end

    # Builds the config the settings currently describe. Upstream panics on an
    # unknown `session-type`; the schema only allows the three nicks, so an
    # unknown one here means the stored value was edited by hand, and the
    # default "Simple" is a better answer than a crash.
    def self.from_settings(settings)
      if settings["session-type"] == "Custom"
        finite
      else
        generated(
          language:   TextGeneration::Language.from_code(settings["text-language"]),
          difficulty: GeneratedTestDifficulty.from_settings_string(settings["session-type"]) ||
            GeneratedTestDifficulty::SIMPLE,
          duration:   TestDuration::ALL.find { |value| value == settings["session-duration"] } ||
            TestDuration::DEFAULT,
        )
      end
    end

    def initialize(kind, language: nil, difficulty: nil, duration: nil)
      @kind = kind
      @language = language
      @difficulty = difficulty
      @duration = duration
    end

    def finite? = @kind == FINITE

    def generated? = @kind == GENERATED

    def ==(other)
      other.is_a?(TestConfig) &&
        other.kind == @kind &&
        other.language == @language &&
        other.difficulty == @difficulty &&
        other.duration == @duration
    end

    alias eql? ==

    def hash = [@kind, @language, @difficulty, @duration].hash
  end

  # Upstream's `TypingTest`: the config a running test was started with, plus
  # when it started. `start_instant` is monotonic (upstream's `Instant`) and is
  # what elapsed time is measured against; `start_timestamp` is wall-clock
  # (upstream's `SystemTime`) and is what the summary records.
  class TypingTest
    attr_reader :config, :start_instant, :start_timestamp

    def initialize(config)
      @config = config
      @start_instant = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @start_timestamp = Time.now
    end

    def elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_instant
  end

  # Upstream's `TestSummary`: everything the results view and the personal-best
  # record need from a finished test.
  class TestSummary
    attr_reader :config, :real_duration, :wpm, :start_timestamp, :accuracy

    def self.build(test:, end_instant:, original:, typed:, keystrokes:)
      new(
        config:          test.config,
        real_duration:   end_instant - test.start_instant,
        start_timestamp: test.start_timestamp,
        wpm:             TextUtils.calculate_wpm(end_instant - test.start_instant, original, typed),
        accuracy:        accuracy_of(keystrokes),
      )
    end

    # Upstream divides the correct keystrokes by the total, which is NaN for a
    # test with no keystrokes at all. A test that was never typed in is 0%
    # accurate rather than unrepresentable.
    def self.accuracy_of(keystrokes)
      if keystrokes.empty?
        0.0
      else
        keystrokes.count { |_timestamp, correct| correct } / keystrokes.length.to_f
      end
    end

    def initialize(config:, real_duration:, wpm:, start_timestamp:, accuracy:)
      @config = config
      @real_duration = real_duration
      @wpm = wpm
      @start_timestamp = start_timestamp
      @accuracy = accuracy
    end
  end
end
