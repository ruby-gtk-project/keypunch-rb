# frozen_string_literal: true

require "gtk4"

# SessionInhibitor keeps the session from logging out in the middle of a
# typing test.
#
# Ported from upstream's src/widgets/window/inhibit.rs, which holds a single
# inhibit cookie on the window and swaps it out whenever a new reason is given.
# The cookie belongs to the GtkApplication, so it is taken and released here
# the same way.
#
class SessionInhibitor
  def initialize(application, window)
    @application = application
    @window = window
    @cookie = nil
  end

  def inhibit(reason)
    end_existing

    @cookie = @application.inhibit(@window, Gtk::ApplicationInhibitFlags::LOGOUT, reason)
  end

  def end_existing
    if @cookie
      @application.uninhibit(@cookie)
      @cookie = nil
    end
  end

  def inhibiting? = !@cookie.nil?
end
