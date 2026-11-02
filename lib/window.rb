# frozen_string_literal: true

require "adwaita"

require_relative "about_dialog"
require_relative "primary_menu"
require_relative "results_view"
require_relative "session_inhibitor"
require_relative "settings"
require_relative "text_view"
require_relative "typing_test_session"
require_relative "window_focus"

# Window is the app's only window: a three-page stack holding the test, the
# results and the "test cancelled" page.
#
# Ported from upstream's src/widgets/window.blp and src/widgets/window.rs. The
# test page is an AdwMultiLayoutView with two layouts — the status in the
# header bar on a wide window, above the text on a narrow one — sharing the
# same five widgets through layout slots, exactly as upstream's Blueprint sets
# it up. The behaviour upstream splits across window/typing_test.rs and
# window/focus.rs lives in the two modules of the same names, mixed in here.
#
# Upstream's src/widgets/window/ui_state.rs is an empty file, so there is
# nothing to port from it.
#
# The breakpoint is where this port diverges in mechanism: upstream declares
# three setters in the Blueprint, but AdwBreakpoint setters can only target
# GObject properties, and the results view's orientation is a plain Ruby
# setter here. The breakpoint's apply and unapply signals do the same three
# changes instead.
#
class Window
  include TypingTestSession
  include WindowFocus

  BREAKPOINT_CONDITION = "max-width: 500sp"

  WIDTH_REQUEST = 360
  HEIGHT_REQUEST = 296

  TEST_TYPE_LABELS = ["Simple", "Advanced", "Custom"].freeze

  DURATION_LABELS = [
    "15 seconds",
    "30 seconds",
    "1 minute",
    "5 minutes",
    "10 minutes",
  ].freeze

  CANCELLED_DESCRIPTION =
    "The test has been cancelled due to an excessive amount of invalid keystrokes. " \
    "This will not affect your typing statistics."

  attr_reader :settings, :application

  def initialize(application, settings, discord_rpc)
    @application = application
    @settings = settings
    @discord_rpc = discord_rpc
    @current_test = nil
    @show_cursor = true
    @cursor_hidden_timestamp = 0
    @unfocus_timeout = nil
  end

  def build
    window.tap do |win|
      win.content = toast_overlay

      toast_overlay.child = main_stack

      main_stack.tap do |stack|
        stack.add_named(test_view, "test")
        stack.add_named(results_toolbar_view, "results")
        stack.add_named(cancelled_toolbar_view, "test-cancelled")
      end

      build_test_view
      build_results_page
      build_cancelled_page
      add_actions
      add_breakpoint

      settings.apply_to(win)

      win.signal_connect("close-request") do
        settings.save_window_state(win)
        false
      end

      # Workaround until dropdowns gain proper flat styling in libadwaita 2.0
      test_type_dropdown.first_child.add_css_class("flat")
      duration_dropdown.first_child.add_css_class("flat")

      setup_focus
      setup_ui_hiding
      show_cursor
      setup_test_config
      ready
    end
  end

  def present = window.present

  def running? = !@current_test.nil?

  # Memoized widget methods

  def window
    @window ||= Adwaita::ApplicationWindow.new(@application).tap do |win|
      win.title = "Keypunch"
      win.width_request = WIDTH_REQUEST
      win.height_request = HEIGHT_REQUEST
    end
  end

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

  def main_stack
    @main_stack ||= Gtk::Stack.new.tap do |stack|
      stack.transition_type = :crossfade
      stack.transition_duration = 200
    end
  end

  def test_view = @test_view ||= Adwaita::MultiLayoutView.new

  # The two layouts of the test page. Both are built from the same slot ids,
  # so the widgets below move between them rather than being duplicated.

  def status_top_layout
    @status_top_layout ||= Adwaita::Layout.new(status_top_toolbar_view).tap do |layout|
      layout.name = "status-top"
    end
  end

  def status_bottom_layout
    @status_bottom_layout ||= Adwaita::Layout.new(status_bottom_toolbar_view).tap do |layout|
      layout.name = "status-bottom"
    end
  end

  def status_top_toolbar_view = @status_top_toolbar_view ||= edge_to_edge_toolbar_view

  def status_bottom_toolbar_view = @status_bottom_toolbar_view ||= edge_to_edge_toolbar_view

  def status_top_header_bar = @status_top_header_bar ||= test_header_bar

  def status_bottom_header_bar = @status_bottom_header_bar ||= test_header_bar

  def status_top_clamp = @status_top_clamp ||= text_clamp

  def status_bottom_clamp = @status_bottom_clamp ||= text_clamp

  def status_bottom_box
    @status_bottom_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.valign = :center
    end
  end

  def status_bottom_status_box
    @status_bottom_status_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.hexpand = false
    end
  end

  # The widgets the two layouts share, one per slot id.

  def stop_button
    @stop_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "arrow-circular-top-right-symbolic"
      button.tooltip_text = "Restart"
    end
  end

  def status_stack
    @status_stack ||= Gtk::Stack.new.tap do |stack|
      stack.transition_type = :crossfade
      stack.transition_duration = 200
    end
  end

  def ready_status_box = @ready_status_box ||= Gtk::Box.new(:horizontal, 6)

  def test_type_dropdown
    @test_type_dropdown ||= Gtk::DropDown.new(Gtk::StringList.new(TEST_TYPE_LABELS)).tap do |dropdown|
      dropdown.tooltip_text = "Test Type"
    end
  end

  def secondary_config_stack = @secondary_config_stack ||= Gtk::Stack.new

  def duration_dropdown
    @duration_dropdown ||= Gtk::DropDown.new(Gtk::StringList.new(DURATION_LABELS)).tap do |dropdown|
      dropdown.tooltip_text = "Test Duration"
    end
  end

  def custom_button
    @custom_button ||= Gtk::Button.new.tap do |button|
      button.child = custom_button_content
      button.add_css_class("flat")
    end
  end

  def custom_button_content
    @custom_button_content ||= Adwaita::ButtonContent.new.tap do |content|
      content.use_underline = true
      content.icon_name = "edit-symbolic"
      content.label = "_Edit Text"
    end
  end

  def status_label
    @status_label ||= Gtk::Label.new.tap do |label|
      label.margin_start = 12
      label.margin_end = 12
      label.add_css_class("heading")
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.primary = true
      button.icon_name = "open-menu-symbolic"
      button.tooltip_text = "Main Menu"
      button.menu_model = PrimaryMenu.build
    end
  end

  def text_view
    @text_view ||= TextView.new(
      on_running_changed:    ->(view) { test_view_running_changed(view) },
      on_typed_text_changed: ->(view) { typed_text_changed(view) },
    )
  end

  def bottom_stack
    @bottom_stack ||= Gtk::Stack.new.tap do |stack|
      stack.transition_type = :crossfade
      stack.transition_duration = 200
      stack.halign = :center
      stack.add_css_class("toolbar-thick")
    end
  end

  def just_start_typing
    @just_start_typing ||= Gtk::Label.new("Just Start Typing").tap do |label|
      label.add_css_class("dim-label")
    end
  end

  # Translators: "Entry" here is the act of entering text
  def focus_button
    @focus_button ||= Gtk::Button.new(label: "_Enable Entry").tap do |button|
      button.use_underline = true
      button.add_css_class("pill")
      button.add_css_class("suggested-action")
    end
  end

  def bottom_stack_empty = @bottom_stack_empty ||= Adwaita::Bin.new

  # The results page.

  def results_toolbar_view = @results_toolbar_view ||= Adwaita::ToolbarView.new

  def results_header_bar = @results_header_bar ||= Adwaita::HeaderBar.new

  def results_window_title = @results_window_title ||= Adwaita::WindowTitle.new("Results", "")

  def results_scrolled_window
    @results_scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
      window.hscrollbar_policy = :never
    end
  end

  def results_box
    @results_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.valign = :center
    end
  end

  def results_view = @results_view ||= ResultsView.new

  def results_bottom_bar = @results_bottom_bar ||= continue_bar

  def results_continue_button = @results_continue_button ||= continue_button

  # The "test cancelled" page.

  def cancelled_toolbar_view = @cancelled_toolbar_view ||= Adwaita::ToolbarView.new

  def cancelled_header_bar = @cancelled_header_bar ||= Adwaita::HeaderBar.new

  def cancelled_status_page
    @cancelled_status_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = "warning-outline-symbolic"
      page.title = "Test Cancelled"
      page.description = CANCELLED_DESCRIPTION
    end
  end

  def frustration_bottom_bar = @frustration_bottom_bar ||= continue_bar

  def frustration_continue_button = @frustration_continue_button ||= continue_button

  def breakpoint
    @breakpoint ||= Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse(BREAKPOINT_CONDITION))
  end

  def inhibitor = @inhibitor ||= SessionInhibitor.new(@application, window)

  private

    def edge_to_edge_toolbar_view
      Adwaita::ToolbarView.new.tap do |view|
        view.extend_content_to_top_edge = true
        view.extend_content_to_bottom_edge = true
      end
    end

    def test_header_bar
      Adwaita::HeaderBar.new.tap do |bar|
        bar.centering_policy = :strict
        bar.add_css_class("test")
      end
    end

    def text_clamp
      Adwaita::Clamp.new.tap do |clamp|
        clamp.maximum_size = 800
        clamp.tightening_threshold = 400
        clamp.margin_top = 48
        clamp.margin_bottom = 48
        clamp.margin_start = 12
        clamp.margin_end = 12
      end
    end

    def continue_bar
      Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :center
        box.add_css_class("toolbar-thick")
      end
    end

    def continue_button
      Gtk::Button.new(label: "_Continue").tap do |button|
        button.use_underline = true
        button.add_css_class("pill")
        button.add_css_class("suggested-action")
      end
    end

    # Each layout has to be complete before it is added: AdwMultiLayoutView
    # binds the slots it finds in a layout when the layout goes in, and a slot
    # added afterwards never gets its child.
    def build_test_view
      build_status_top_layout
      build_status_bottom_layout
      build_shared_slots

      test_view.tap do |view|
        view.add_layout(status_top_layout)
        view.add_layout(status_bottom_layout)

        view.set_child("stop_button", stop_button)
        view.set_child("test_status", status_stack)
        view.set_child("menu_button", menu_button)
        view.set_child("text_view", text_view.build)
        view.set_child("bottom_stack", bottom_stack)

        view.layout_name = "status-top"
      end
    end

    def build_status_top_layout
      status_top_toolbar_view.tap do |view|
        view.add_top_bar(status_top_header_bar)
        view.content = status_top_clamp
        view.add_bottom_bar(Adwaita::LayoutSlot.new("bottom_stack"))

        status_top_header_bar.tap do |bar|
          bar.pack_start(Adwaita::LayoutSlot.new("stop_button"))
          bar.title_widget = Adwaita::LayoutSlot.new("test_status")
          bar.pack_end(Adwaita::LayoutSlot.new("menu_button"))
        end

        status_top_clamp.child = Adwaita::LayoutSlot.new("text_view")
      end
    end

    def build_status_bottom_layout
      status_bottom_toolbar_view.tap do |view|
        view.add_top_bar(status_bottom_header_bar)
        view.content = status_bottom_clamp
        view.add_bottom_bar(Adwaita::LayoutSlot.new("bottom_stack"))

        status_bottom_header_bar.tap do |bar|
          bar.pack_start(Adwaita::LayoutSlot.new("stop_button"))
          bar.pack_end(Adwaita::LayoutSlot.new("menu_button"))
        end

        status_bottom_clamp.child = status_bottom_box

        status_bottom_box.tap do |box|
          box.append(status_bottom_status_box)
          box.append(Adwaita::LayoutSlot.new("text_view"))

          status_bottom_status_box.append(Adwaita::LayoutSlot.new("test_status"))
        end
      end
    end

    def build_shared_slots
      status_stack.tap do |stack|
        stack.add_named(ready_status_box, "ready")
        stack.add_named(status_label, "running")

        ready_status_box.tap do |box|
          box.append(test_type_dropdown)
          box.append(secondary_config_stack)

          secondary_config_stack.tap do |config|
            config.add_child(duration_dropdown)
            config.add_child(custom_button)
          end
        end
      end

      bottom_stack.tap do |stack|
        stack.add_child(just_start_typing)
        stack.add_child(focus_button)
        stack.add_child(bottom_stack_empty)
      end

      stop_button.signal_connect("clicked") { ready }
    end

    def build_results_page
      results_toolbar_view.tap do |view|
        view.add_top_bar(results_header_bar)
        view.content = results_scrolled_window
        view.add_bottom_bar(results_bottom_bar)

        results_header_bar.title_widget = results_window_title

        results_scrolled_window.child = results_box
        results_box.append(results_view.build)

        results_bottom_bar.append(results_continue_button)
        results_continue_button.signal_connect("clicked") { ready }
      end
    end

    def build_cancelled_page
      cancelled_toolbar_view.tap do |view|
        view.add_top_bar(cancelled_header_bar)
        view.content = cancelled_status_page
        view.add_bottom_bar(frustration_bottom_bar)

        frustration_bottom_bar.append(frustration_continue_button)
        frustration_continue_button.signal_connect("clicked") { ready }
      end
    end

    # Actions — upstream installs these in `class_init`.

    def add_actions
      window.add_action(about_action)
      window.add_action(text_language_action)
      window.add_action(cancel_test_action)
    end

    def about_action
      @about_action ||= simple_action("about") { show_about_dialog }
    end

    def text_language_action
      @text_language_action ||= simple_action("text-language-dialog") { show_text_language_dialog }
    end

    def cancel_test_action
      @cancel_test_action ||= simple_action("cancel-test") { ready }
    end

    def simple_action(name, &block)
      Gio::SimpleAction.new(name).tap do |action|
        action.signal_connect("activate") { block.call }
      end
    end

    def add_breakpoint
      breakpoint.tap do |point|
        point.signal_connect("apply") { apply_narrow_layout(true) }
        point.signal_connect("unapply") { apply_narrow_layout(false) }

        window.add_breakpoint(point)
      end
    end

    def apply_narrow_layout(narrow)
      if narrow
        results_view.orientation = :vertical
        test_view.layout_name = "status-bottom"
        status_label.xalign = 0
      else
        results_view.orientation = :horizontal
        test_view.layout_name = "status-top"
        status_label.xalign = 0.5
      end
    end

    def show_about_dialog
      if !running? && window.visible_dialog.nil?
        AboutDialog.new(@application.application_id, Keypunch::Rb::VERSION).build.tap do |dialog|
          dialog.signal_connect("closed") { focus_text_view }
          dialog.present(window)
        end
      end
    end
end
