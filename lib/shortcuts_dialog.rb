# frozen_string_literal: true

require "adwaita"

require_relative "translations"

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
# Neither upstream's .ui file nor this class sets the dialog's title:
# AdwShortcutsDialog defaults it to "Keyboard Shortcuts" out of libadwaita's
# own catalogue, which is already translated in every locale libadwaita ships.
#
class ShortcutsDialog < Adwaita::ShortcutsDialog
  include Translations::Helpers

  def build
    tap do |dialog|
      dialog.add(section)
    end
  end

  def section
    @section ||= Adwaita::ShortcutsSection.new.tap do |section|
      section.title = p_("shortcut dialog", "General")
      items.each { |title, accelerator, action| section.add(item(title, accelerator, action)) }
    end
  end

  private

    # Each item is [title, accelerator, action_name]; exactly one of the last
    # two is set, matching the .ui file.
    #
    # The titles carry the same msgctxt as upstream's .ui file — titles this
    # short need the disambiguation, since "General" is a word a translator
    # renders differently in a shortcut list than in a menu. Both the context
    # and the title have to be written out at the lookup, because that literal
    # pair is what the pot is extracted from; neither can come from a
    # constant, and a constant could not be translated this early anyway.
    def items
      [
        [p_("shortcut dialog", "Open Menu"), "F10", nil],
        [p_("shortcut dialog", "Text Language"), nil, "win.text-language-dialog"],
        [p_("shortcut dialog", "Cancel Test"), nil, "win.cancel-test"],
        [p_("shortcut dialog", "Keyboard Shortcuts"), nil, "app.shortcuts"],
        [p_("shortcut dialog", "Close Window"), nil, "window.close"],
        [p_("shortcut dialog", "Text Language"), nil, "app.quit"],
      ]
    end

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
