# frozen_string_literal: true

require "gtk4"

# WindowFocus is the focus affordance: when the typing surface loses focus for
# long enough, it blurs and an "Enable Entry" button appears in its place.
#
# Ported from upstream's src/widgets/window/focus.rs, and mixed into Window.
#
# Upstream keeps both the pending timeout and the timestamp it was scheduled
# at, and cancels the previous timeout only once both have a previous value and
# the previous one is less than the timeout old — in effect, debouncing a burst
# of focus changes so only the last one gets to blur the text. Cancelling the
# pending timeout outright is the same debounce without the two warm-up events,
# so that is what happens here.
#
module WindowFocus
  UNFOCUSED_TIMEOUT_MILLIS = 2000

  def setup_focus
    focus_button.signal_connect("clicked") { focus_text_view }
    window.signal_connect("notify::focus-widget") { focus_widget_changed }
  end

  def text_view_focused? = window.focus == text_view.root

  def focus_text_view = window.set_focus(text_view.root)

  private

    def focus_widget_changed
      if text_view_focused?
        show_focused_affordance
      else
        schedule_unfocused_affordance
      end
    end

    def show_focused_affordance
      if running?
        bottom_stack.visible_child = bottom_stack_empty
      else
        bottom_stack.visible_child = just_start_typing
      end

      text_view.remove_css_class("unfocused")
    end

    def schedule_unfocused_affordance
      cancel_unfocus_timeout

      @unfocus_timeout = GLib::Timeout.add(UNFOCUSED_TIMEOUT_MILLIS) do
        @unfocus_timeout = nil
        show_unfocused_affordance
        false
      end
    end

    def cancel_unfocus_timeout
      if @unfocus_timeout
        GLib::Source.remove(@unfocus_timeout)
        @unfocus_timeout = nil
      end
    end

    # Only blur the text if the focus is still gone, no dialog has taken it,
    # and the test page is the one showing.
    def show_unfocused_affordance
      if !text_view_focused? && window.visible_dialog.nil? && main_stack.visible_child_name == "test"
        bottom_stack.visible_child = focus_button
        text_view.add_css_class("unfocused")
      end
    end
end
