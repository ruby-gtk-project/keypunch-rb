# frozen_string_literal: true

require "adwaita"

require_relative "translations"

# AboutDialog is the app's About window.
#
# Ported from `show_about_dialog` in upstream's src/widgets/window.rs. Upstream
# builds the dialog with `adw::AboutDialog::from_appdata`, which reads the app
# name, summary, licence, version and link list out of the metainfo file in the
# GResource bundle, and then adds the credits in source. There is no GResource
# bundle here and `Adwaita::AboutDialog.from_appdata` is not bound in Ruby, so
# the values that upstream's
# data/no.bragefuglseth.Keypunch.metainfo.xml.in.in supplies are set directly
# — the same name, summary, licence, developer and urls — and the credit,
# acknowledgement, donate-link and other-app calls follow upstream exactly.
#
class AboutDialog < Adwaita::AboutDialog
  include Translations::Helpers

  # Upstream reads this from the metainfo file, where it is translatable and a
  # few locales do translate it, so it goes through the catalogue here too.
  APPLICATION_NAME = N_("Keypunch")
  DEVELOPER_NAME = "Brage Fuglseth"
  COPYRIGHT = "© 2024–2026 Brage Fuglseth"
  COMMENTS = N_("Practice your typing skills")
  RELEASE_NOTES_VERSION = "7.0"

  HOMEPAGE = "https://apps.gnome.org/Keypunch"
  ISSUE_URL = "https://github.com/bragefuglseth/keypunch/issues"
  SUPPORT_URL = "https://matrix.to/#/#keypunch:gnome.org"
  DONATE_URL = "https://bragefuglseth.no/donate.html"

  DEVELOPERS = ["Brage Fuglseth https://bragefuglseth.no"].freeze

  ORTHOGRAPHY_CREDITS = [
    "Angelo Verlain Shema https://www.vixalien.com/",
    "Arnob Goswami",
    "Daniel Uhrinyi",
    "Fabio Lovato https://loviuz.it/",
    "Gregor Niehl https://gregorni.gitlab.io/",
    "Hadi Azarnasab https://hadi7546.ir/",
    "Ibrahim Muhammad",
    "Kim Jimin https://developomp.com",
    "Shellheim",
    "Tamazight teachers of Tizi Ouzou",
    "Urtsi Santsi",
    "Yevhen Popok",
  ].freeze

  SPECIAL_THANKS = ["Sophie Herold https://www.patreon.com/sophieh"].freeze

  # Metainfo for the app Fretboard.
  # <https://github.com/bragefuglseth/fretboard>
  OTHER_APP_ID = "no.bragefuglseth.Fretboard"
  OTHER_APP_NAME = N_("Fretboard")
  OTHER_APP_DESCRIPTION = N_("Look up guitar chords")

  # Translators: Replace "translator-credits" with your names, one name per line
  TRANSLATOR_CREDITS = N_("translator-credits")

  def initialize(application_id, version)
    super()
    @application_id = application_id
    @version = version
  end

  def build
    tap do |dialog|
      dialog.application_name = _(APPLICATION_NAME)
      dialog.application_icon = @application_id
      dialog.developer_name = DEVELOPER_NAME
      dialog.version = @version
      dialog.release_notes_version = RELEASE_NOTES_VERSION
      dialog.comments = _(COMMENTS)
      dialog.license_type = Gtk::License::GPL_3_0
      dialog.copyright = COPYRIGHT
      dialog.website = HOMEPAGE
      dialog.issue_url = ISSUE_URL
      dialog.support_url = SUPPORT_URL
      dialog.developers = DEVELOPERS

      dialog.add_link(_("Donate"), DONATE_URL)
      dialog.add_credit_section(_("Orthography by"), ORTHOGRAPHY_CREDITS)
      dialog.add_acknowledgement_section(_("Special thanks to"), SPECIAL_THANKS)
      dialog.add_other_app(OTHER_APP_ID, _(OTHER_APP_NAME), _(OTHER_APP_DESCRIPTION))

      translated_credits.then do |credits|
        if credits
          dialog.translator_credits = credits
        end
      end
    end
  end

  private

    # Upstream sets the credits from the catalogue unconditionally. gettext
    # hands back the msgid when a locale has not translated it, and
    # "translator-credits" is not a name to show anyone, so the credits are
    # set only once a catalogue has filled them in — the same test every
    # GNOME app makes of this message.
    # Named around the property rather than after it: `translator_credits` is
    # AdwAboutDialog's own reader, and a method of that name here would hide
    # it.
    def translated_credits
      _(TRANSLATOR_CREDITS).then do |credits|
        if credits == TRANSLATOR_CREDITS
          nil
        else
          credits
        end
      end
    end
end
