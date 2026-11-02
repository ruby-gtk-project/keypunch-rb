# frozen_string_literal: true

require "adwaita"

# CustomTextDialog is the editor for the text a "Custom" test runs over.
#
# A direct port of upstream's src/widgets/custom_text_dialog.blp and
# src/widgets/custom_text_dialog.rs: the title fades into the header bar as
# the content scrolls, the placeholder hides as soon as there is text, Save is
# insensitive while the text is only whitespace, and closing the dialog with
# unsaved changes reports them so the window can offer to restore them.
#
# Upstream emits a `discard` GObject signal carrying the abandoned text;
# `on_discard` is the same thing as a callback, because a plain Ruby class
# cannot declare GObject signals.
#
class CustomTextDialog < Adwaita::Dialog
  CONTENT_WIDTH = 450
  CONTENT_HEIGHT = 500

  # `initial_override` is the text to start from when the window is reopening
  # the dialog after a discard; without it the dialog starts from the stored
  # custom text.
  def initialize(settings, initial_override: nil, on_discard: nil)
    super()
    @settings = settings
    @initial_text = initial_override || settings["custom-text"]
    @on_discard = on_discard
    @apply_changes = false

    self.title = "Custom Text"
    self.content_width = CONTENT_WIDTH
    self.content_height = CONTENT_HEIGHT
  end

  def build
    tap do |dialog|
      dialog.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scrolled_window
        view.add_bottom_bar(bottom_bar)

        scrolled_window.child = content_box

        content_box.tap do |box|
          box.append(title_label)
          box.append(overlay)

          overlay.tap do |area|
            area.child = text_view
            area.add_overlay(placeholder)
          end
        end

        bottom_bar.append(save_button)
      end

      buffer.text = @initial_text
      text_view.grab_focus
      buffer.select_range(buffer.start_iter, buffer.end_iter)

      scrolled_window.vadjustment.signal_connect("notify::value") { sync_header_title }
      sync_header_title

      buffer.signal_connect("notify::text") do
        update_from_text
      end

      save_button.signal_connect("clicked") do
        save
      end

      dialog.signal_connect("closed") do
        closed
      end

      update_from_text
    end
  end

  # The text currently in the editor.
  def text = buffer.get_text(buffer.start_iter, buffer.end_iter, false)

  # Memoized widget methods

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.show_title = false
    end
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
      window.hscrollbar_policy = :never
      window.propagate_natural_height = true
    end
  end

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.margin_start = 12
      box.margin_end = 12
      box.margin_bottom = 12
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new("Custom Text").tap do |label|
      label.margin_bottom = 24
      label.add_css_class("title-1")
    end
  end

  def overlay = @overlay ||= Gtk::Overlay.new

  def placeholder
    @placeholder ||= Gtk::Label.new("Insert custom text…").tap do |label|
      label.valign = :start
      label.halign = :start
      label.margin_top = 12
      label.margin_start = 12
      label.margin_end = 12
      label.add_css_class("dim-label")
    end
  end

  def text_view
    @text_view ||= Gtk::TextView.new.tap do |view|
      view.vexpand = true
      view.wrap_mode = :word_char
      view.accepts_tab = false
      view.add_css_class("card")
      view.add_css_class("card-text-view")
    end
  end

  def bottom_bar
    @bottom_bar ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.halign = :center
      box.valign = :center
      box.add_css_class("toolbar-thick")
    end
  end

  def save_button
    @save_button ||= Gtk::Button.new(label: "_Save").tap do |button|
      button.use_underline = true
      button.add_css_class("pill")
      button.add_css_class("suggested-action")
    end
  end

  def buffer = text_view.buffer

  private

    # Upstream binds the scroll position to the header bar's `show-title` with
    # `sync_create`, so the binding also sets the initial state.
    def sync_header_title
      header_bar.show_title = scrolled_window.vadjustment.value.positive?
    end

    def update_from_text
      current = text

      placeholder.visible = current.empty?
      save_button.sensitive = current.match?(/\S/)
    end

    def save
      @apply_changes = true
      @settings["custom-text"] = text
      close
    end

    def closed
      if changed? && !@apply_changes
        @on_discard&.call(text)
      end
    end

    def changed? = @settings["custom-text"] != text
end
