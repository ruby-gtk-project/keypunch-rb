# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "rb/version"

require_relative "../discord_rpc"
require_relative "../settings"
require_relative "../shortcuts_dialog"
require_relative "../style"
require_relative "../translations"
require_relative "../window"

module Keypunch
  # The application: one window, the settings behind it, and the Discord rich
  # presence reporter.
  #
  # Ported from upstream's src/application.rs and src/main.rs. Upstream
  # subclasses AdwApplication to hold the settings and the presence reporter,
  # installs the `quit` action and the accelerators, and turns the
  # `text-language` settings key into an action the language rows bind to. The
  # Ruby bindings cannot subclass GApplication usefully, so the same things
  # hang off this plain object instead, and the `text-language` action is a
  # stateful GSimpleAction that writes the setting — upstream gets that action
  # from `gio::Settings::create_action`, which has no equivalent here because
  # the settings are not GSettings.
  #
  # Upstream also registers a GResource bundle in main.rs; this port has none
  # (the stylesheet, icons and illustration are read from data/). The gettext
  # setup that follows it in main.rs is `Translations.bind` here, which reads
  # the locale's catalogue straight out of po/ — see lib/translations.rb for
  # why there is no compiled domain to bind instead.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APPLICATION_ID = "org.rubygtkproject.Keypunch"

    ACCELERATORS = {
      "win.text-language-dialog" => ["<primary>comma"],
      "win.cancel-test"          => ["Escape"],
      "window.close"             => ["<primary>w"],
      "app.quit"                 => ["<primary>q"],
    }.freeze

    def build
      app.tap do
        app.signal_connect("startup") do
          Translations.bind
          Adwaita.init
          Style.load

          app.add_action(quit_action)
          app.add_action(shortcuts_action)
          app.add_action(text_language_action)

          ACCELERATORS.each { |action, accels| app.set_accels_for_action(action, accels) }
        end

        app.signal_connect("activate") do
          main_window.build
          main_window.present
        end

        app.signal_connect("shutdown") do
          discord_rpc.shutdown
        end
      end
    end

    def run = app.run([])

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the window is Adwaita.
    def app = @app ||= Gtk::Application.new(APPLICATION_ID, :default_flags)

    def settings = @settings ||= Settings.new

    def discord_rpc = @discord_rpc ||= DiscordRpc.new

    def main_window = @main_window ||= Window.new(app, settings, discord_rpc)

    def quit_action
      @quit_action ||= Gio::SimpleAction.new("quit").tap do |action|
        action.signal_connect("activate") { app.quit }
      end
    end

    def shortcuts_action
      @shortcuts_action ||= Gio::SimpleAction.new("shortcuts").tap do |action|
        action.signal_connect("activate") { show_shortcuts_dialog }
      end
    end

    # Upstream's `settings.create_action("text-language")`: the language rows
    # are check buttons bound to this action, so picking one sets the state,
    # and the state is what the setting stores.
    def text_language_action
      @text_language_action ||= Gio::SimpleAction.new(
        "text-language",
        GLib::VariantType.new("s"),
        GLib::Variant.new(settings["text-language"]),
      ).tap do |action|
        action.signal_connect("activate") { |_action, parameter| change_text_language(parameter) }
      end
    end

    private

      def change_text_language(parameter)
        text_language_action.set_state(parameter)
        settings["text-language"] = parameter.get_string.first
      end

      def show_shortcuts_dialog
        ShortcutsDialog.new.build.present(main_window.window)
      end
  end
end
