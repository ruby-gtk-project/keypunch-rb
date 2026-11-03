# frozen_string_literal: true

require "gtk4"

require_relative "translations"

# PrimaryMenu is the model behind the window's main menu button.
#
# Ported from the `menu primary_menu` block at the end of upstream's
# src/widgets/window.blp: one section with three items, in the same order and
# with the same actions. The underscores are mnemonics, as in the Blueprint.
#
module PrimaryMenu
  include Translations::Helpers

  # The labels are msgids here and translated where the section is built: a
  # constant is frozen before the catalogue is bound.
  ITEMS = [
    [N_("Text _Language"), "win.text-language-dialog"],
    [N_("_Keyboard Shortcuts"), "app.shortcuts"],
    [N_("_About Keypunch"), "win.about"],
  ].freeze

  module_function

  def build
    Gio::Menu.new.tap do |menu|
      menu.append_section(nil, section)
    end
  end

  def section
    Gio::Menu.new.tap do |menu|
      ITEMS.each { |label, action| menu.append(_(label), action) }
    end
  end
end
