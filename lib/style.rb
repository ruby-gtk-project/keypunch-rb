# frozen_string_literal: true

require "gtk4"

# Style loads the app's stylesheet into the default display.
#
# Ported from upstream's data/resources/style.css, which upstream ships inside
# its GResource bundle and GTK picks up automatically from the application's
# resource base path. There is no GResource bundle here, so the stylesheet is
# read from data/style.css and added to the display as an application-priority
# provider — the same priority GTK gives the resource-based one.
#
module Style
  PATH = File.expand_path("../data/style.css", __dir__)

  # Upstream's custom symbolic icons, which it ships inside its GResource
  # bundle; GTK finds them there through the application's resource base path.
  # Without a bundle they are a search path on the display's icon theme
  # instead, which is the same lookup by a different route — a search path
  # wants the theme directory in the middle, so they sit under hicolor/.
  ICON_PATH = File.expand_path("../data/icons", __dir__)

  # The style class the composed text view's root widget carries, standing in
  # for upstream's `KpTextView` CSS name.
  TEXT_VIEW_CLASS = "kp-text-view"

  # The style class the composed results view's root widget carries, standing
  # in for upstream's `KpResultsView` CSS name.
  RESULTS_VIEW_CLASS = "kp-results-view"

  module_function

  def load
    Gtk::StyleContext.add_provider_for_display(
      Gdk::Display.default,
      provider,
      Gtk::StyleProvider::PRIORITY_APPLICATION,
    )

    Gtk::IconTheme.get_for_display(Gdk::Display.default).add_search_path(ICON_PATH)
  end

  def provider
    @provider ||= Gtk::CssProvider.new.tap do |css|
      css.load_from_path(PATH)
    end
  end
end
