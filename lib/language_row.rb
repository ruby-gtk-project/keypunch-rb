# frozen_string_literal: true

require "adwaita"

# LanguageRow is one language in the text language dialog's list.
#
# Ported from the `language_row` function at the bottom of upstream's
# src/widgets/text_language_dialog.rs: an AdwActionRow titled with the
# language's own name, with a check button as its prefix and activatable
# widget. The check button carries the `app.text-language` action with the
# language code as its target, so GTK keeps exactly one of them checked and
# writing the setting is the action's job rather than the row's.
#
class LanguageRow
  ACTION_NAME = "app.text-language"

  def initialize(language)
    @language = language
  end

  def build
    row.tap do |action_row|
      action_row.add_prefix(check_button)
      action_row.activatable_widget = check_button
    end
  end

  def row
    @row ||= Adwaita::ActionRow.new.tap do |action_row|
      action_row.title = @language.name
    end
  end

  def check_button
    @check_button ||= Gtk::CheckButton.new.tap do |button|
      button.action_name = ACTION_NAME
      button.set_action_target_value(GLib::Variant.new(@language.code))
    end
  end
end
