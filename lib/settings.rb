# frozen_string_literal: true

require "fileutils"
require "json"

require_relative "translations"

# Settings holds the same keys as upstream's
# data/no.bragefuglseth.Keypunch.gschema.xml.in, with the same defaults and the
# same semantics.
#
# Upstream uses GSettings, which needs a compiled schema installed into the
# system's glib-2.0/schemas directory before the app will even start. Requiring
# an install step to run the app from a checkout is worse than the alternative,
# so the keys are backed by a small JSON file under XDG_CONFIG_HOME instead.
# The two schema enums are kept as the value arrays below, because the nicks
# are what the stored values and the personal-best records are keyed by.
#
# `connect_changed` and `bind_dropdown_selected` stand in for
# `gio::Settings::connect_changed` and upstream's src/settings.rs, which binds
# a dropdown's `selected` index to an enum-valued key in both directions.
#
class Settings
  include Translations::Helpers

  # Must match their corresponding schema enums
  SESSION_TYPE_VALUES = %w[Simple Advanced Custom].freeze
  SESSION_DURATION_VALUES = %w[Sec15 Sec30 Min1 Min5 Min10].freeze

  DEFAULTS = {
    "window-width"     => 900,
    "window-height"    => 450,
    "window-maximized" => false,
    "session-type"     => "Simple",
    "session-duration" => "Sec30",
    "text-language"    => "en",
    "recent-languages" => [],
    "custom-text"      => "The quick brown fox jumps over the lazy dog.",
    "personal-best"    => [],
  }.freeze

  # Two of those defaults are translatable in upstream's schema, so a locale
  # starts on its own word list with a pangram of its own language rather than
  # on English's. A gschema default is GVariant source text, which is why the
  # quotation marks are part of the msgid; they come off the translation
  # again. A locale whose code has no word list falls back to English in
  # `TextGeneration::Language.from_code`, which is what the translator comment
  # on the first of these promises.
  #
  # Translators: Insert the language code of your language here, for example "nb" for Norwegian Bokmaal. Do not remove the quotation marks. It's doesn't matter if there isn't a word list for the language in `data/word_lists` right now, the app will fall back to English in that case and start using the list if it becomes available in the future.
  DEFAULT_TEXT_LANGUAGE = N_("\"en\"")

  # Translators: This is the default text for custom typing sessions. Do not translate it literally, and do not remove the quotation marks. Replace it with an appropriate "sample sentence" from your language instead. The original text is an English pangram, so you can e.g. find a pangram in your language: https://clagnut.com/blog/2380
  DEFAULT_CUSTOM_TEXT = N_("\"The quick brown fox jumps over the lazy dog.\"")

  QUOTE = "\""

  def initialize(path: nil)
    @path = path || default_path
    @values = localized_defaults.merge(read)
    @listeners = {}
  end

  def location = @path

  def [](key) = @values.fetch(key.to_s, localized_defaults[key.to_s])

  def localized_defaults
    @localized_defaults ||= DEFAULTS.merge(
      "text-language" => unquote(_(DEFAULT_TEXT_LANGUAGE)),
      "custom-text"   => unquote(_(DEFAULT_CUSTOM_TEXT)),
    )
  end

  def []=(key, value)
    @values[key.to_s] = value
    write
    notify(key.to_s)
    value
  end

  # Upstream's `settings.connect_changed(Some(key), ...)`. The block is called
  # whenever that key is written, including when a bound dropdown writes it.
  def connect_changed(key, &block)
    @listeners[key.to_s] ||= []
    @listeners[key.to_s] << block
  end

  # Upstream's `settings::bind_dropdown_selected`: the dropdown's selected
  # index maps to the nick at that index in `values`, and back.
  def bind_dropdown_selected(dropdown, key, values)
    dropdown.selected = values.index(self[key]) || 0

    dropdown.signal_connect("notify::selected") do
      chosen = values[dropdown.selected]

      if chosen && chosen != self[key]
        self[key] = chosen
      end
    end

    connect_changed(key) do
      index = values.index(self[key]) || 0

      if dropdown.selected != index
        dropdown.selected = index
      end
    end
  end

  # Named accessors for the keys the app reads most, so callers do not repeat
  # the string keys.
  DEFAULTS.each_key do |key|
    method_name = key.tr("-", "_")
    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }
  end

  # Restores the window geometry recorded by the previous run. Upstream's
  # `load_window_size`.
  def apply_to(window)
    window.set_default_size(self["window-width"], self["window-height"])

    if self["window-maximized"]
      window.maximize
    end
  end

  # Records the window geometry for the next run. Upstream's
  # `save_window_size`.
  def save_window_state(window)
    @values["window-width"] = window.default_width
    @values["window-height"] = window.default_height
    @values["window-maximized"] = window.maximized?
    write
  end

  private

    # A GVariant string literal, as a translated schema default arrives, down
    # to the string it stands for.
    def unquote(value)
      value.delete_prefix(QUOTE).delete_suffix(QUOTE)
    end

    def notify(key)
      @listeners.fetch(key, []).each(&:call)
    end

    def default_path
      base = ENV["XDG_CONFIG_HOME"] || File.join(Dir.home, ".config")
      File.join(base, "keypunch-rb", "settings.json")
    end

    def read
      if File.exist?(@path)
        parse(File.read(@path))
      else
        {}
      end
    end

    # A settings file written by a newer version, or edited by hand into
    # something that is not JSON at all, must not stop the app from starting.
    # The defaults are a better answer than a crash.
    def parse(contents)
      begin
        parsed = JSON.parse(contents)
      rescue JSON::ParserError
        parsed = {}
      end

      if parsed.is_a?(Hash)
        parsed.slice(*DEFAULTS.keys)
      else
        {}
      end
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, "#{JSON.pretty_generate(@values)}\n")
    end
end
