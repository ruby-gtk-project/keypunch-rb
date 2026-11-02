# frozen_string_literal: true

require "adwaita"

# ShortcutsDialog lists the keyboard shortcuts.
#
# A direct port of upstream's data/resources/shortcuts-dialog.ui, which is a
# standalone AdwShortcutsDialog with one "General" section and six items. Five
# of them name an action rather than an accelerator, and AdwShortcutsItem looks
# the accelerator up from the application's accels for that action.
#
# The sixth item is labelled "Text Language" in upstream's .ui file even though
# its action is `app.quit` — upstream's own copy/paste slip, kept here because
# upstream is the spec for this port.
#
class ShortcutsDialog < Adwaita::ShortcutsDialog
  SECTION_TITLE = "General"

  # Each item is [title, accelerator, action_name]; exactly one of the last two
  # is set, matching the .ui file.
  ITEMS = [
    ["Open Menu", "F10", nil],
    ["Text Language", nil, "win.text-language-dialog"],
    ["Cancel Test", nil, "win.cancel-test"],
    ["Keyboard Shortcuts", nil, "app.shortcuts"],
    ["Close Window", nil, "window.close"],
    ["Text Language", nil, "app.quit"],
  ].freeze

  def initialize
    super()
    self.title = "Keyboard Shortcuts"
  end

  def build
    tap do |dialog|
      dialog.add(section)
    end
  end

  def section
    @section ||= Adwaita::ShortcutsSection.new.tap do |section|
      section.title = SECTION_TITLE
      ITEMS.each { |title, accelerator, action| section.add(item(title, accelerator, action)) }
    end
  end

  private

    # Positional, not keyword, arguments — even though the error a no-argument
    # `new` raises advertises the signature as "title: utf8, accelerator: utf8".
    def item(title, accelerator, action)
      Adwaita::ShortcutsItem.new(title, accelerator.to_s).tap do |shortcut|
        if action
          shortcut.action_name = action
        end
      end
    end
end
