# frozen_string_literal: true

require "adwaita"

require_relative "language_row"
require_relative "text_generation"
require_relative "translations"

# TextLanguageDialog lets the user pick the language generated text is drawn
# from, and explains how to get a new one added.
#
# A direct port of upstream's src/widgets/text_language_dialog.blp and
# src/widgets/text_language_dialog.rs: an AdwDialog holding an
# AdwNavigationView with a "choose-language" page and an "add-language" page,
# the list split into Recent and Other, a search that swaps the list for a
# result list or a "No Matches" page, and the recent languages recorded when
# the dialog closes.
#
# Upstream normalises both the query and the language names with the
# `unidecode` crate so that "espanol" finds "Español". There is no unidecode
# here; decomposing to NFD and dropping the combining marks does the same job
# for the accented Latin names in the list, and leaves the non-Latin ones —
# which have nothing to fold — alone.
#
class TextLanguageDialog < Adwaita::Dialog
  include Translations::Helpers

  LANGUAGE_REQUEST_URL =
    "https://github.com/bragefuglseth/keypunch/issues/new?assignees=&labels=new+language&projects=&template=language_request.yaml&title=%5BLanguage+Request%5D%3A+"

  ILLUSTRATION = File.expand_path("../data/assets/multilingual.svg", __dir__)

  CONTENT_WIDTH = 450
  CONTENT_HEIGHT = 500

  # How many languages the Recent group remembers, upstream's `.take(3)`.
  RECENT_LIMIT = 3

  ADD_LANGUAGE_DESCRIPTION = N_(
    "You can help add a new text language to Keypunch by submitting a language request on GitHub. " \
    "A GitHub account and some language knowledge is required.",
  )

  def self.normalize(string)
    string.downcase.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
  end

  def initialize(settings)
    super()
    @settings = settings

    self.title = _("Text Language")
    self.content_width = CONTENT_WIDTH
    self.content_height = CONTENT_HEIGHT
  end

  def build
    tap do |dialog|
      dialog.child = navigation_view

      navigation_view.tap do |view|
        view.add(choose_language_page)
        view.add(add_language_page)
      end

      build_choose_language_page
      build_add_language_page

      populate_list

      dialog.focus_widget = search_entry

      scrolled_window.vadjustment.signal_connect("notify::value") { sync_header_title }
      sync_header_title

      search_entry.signal_connect("search-changed") { update_search_state }
      search_entry.signal_connect("stop-search") { close }

      dialog.signal_connect("closed") { record_recent_languages }

      update_search_state
    end
  end

  # The language the settings currently name.
  def current_language = TextGeneration::Language.from_code(@settings["text-language"])

  # The languages the settings remember, in order, current one excluded.
  def recent_languages
    @settings["recent-languages"]
      .filter_map { |code| TextGeneration::Language::ALL.find { |language| language.code == code } }
      .reject { |language| language == current_language }
  end

  # Memoized widget methods

  def navigation_view = @navigation_view ||= Adwaita::NavigationView.new

  # Adwaita::NavigationPage takes its child and title positionally, so the
  # toolbar view has to exist first.
  def choose_language_page
    @choose_language_page ||= Adwaita::NavigationPage.new(toolbar_view, _("Text Language")).tap do |page|
      page.tag = "choose-language"
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def add_language_button
    @add_language_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "plus-large-symbolic"
      button.tooltip_text = _("Add Language")
      button.action_name = "navigation.push"
      button.set_action_target_value(GLib::Variant.new("add-language"))
    end
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
      window.hscrollbar_policy = :never
      window.propagate_natural_height = true
      window.vexpand = true
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
    @title_label ||= Gtk::Label.new(_("Text Language")).tap do |label|
      label.margin_bottom = 24
      label.add_css_class("title-1")
    end
  end

  def search_clamp
    @search_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = 360
    end
  end

  def search_entry
    @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
      entry.placeholder_text = _("Search languages…")
      entry.margin_bottom = 18
      entry.add_css_class("pill-entry")
    end
  end

  def stack
    @stack ||= Gtk::Stack.new.tap do |widget|
      widget.vhomogeneous = false
      widget.transition_type = :crossfade
      widget.transition_duration = 100
      widget.vexpand = true
    end
  end

  def list_box
    @list_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
      box.add_css_class("background")
    end
  end

  def group_recent
    @group_recent ||= Adwaita::PreferencesGroup.new.tap do |group|
      # Recent languages in text languages list
      # Translators: Recent languages in text languages list
      group.title = _("Recent")
    end
  end

  def group_other
    @group_other ||= Adwaita::PreferencesGroup.new.tap do |group|
      # Other languages in text languages list
      # Translators: Other languages in text languages list
      group.title = _("Other")
    end
  end

  def search_results_box
    @search_results_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.vexpand = true
    end
  end

  def search_list
    @search_list ||= Gtk::ListBox.new.tap do |list|
      list.selection_mode = :none
      list.add_css_class("boxed-list")
    end
  end

  def no_results_box
    @no_results_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.vexpand = false
    end
  end

  def no_results_inner_box
    @no_results_inner_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
      box.halign = :center
      box.valign = :center
      box.vexpand = true
    end
  end

  def no_results_icon
    @no_results_icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = "language-symbolic"
      image.vexpand = false
      image.accessible_role = :presentation
      image.add_css_class("status-icon")
      image.add_css_class("dim-label")
    end
  end

  def no_results_title
    @no_results_title ||= Gtk::Label.new(_("No Matches")).tap do |label|
      label.add_css_class("title-2")
    end
  end

  def no_results_description = @no_results_description ||= Gtk::Label.new(_("Try a different search"))

  def add_language_page
    @add_language_page ||= Adwaita::NavigationPage.new(add_language_toolbar_view, _("Add Language")).tap do |page|
      page.tag = "add-language"
    end
  end

  def add_language_toolbar_view = @add_language_toolbar_view ||= Adwaita::ToolbarView.new

  def add_language_header_bar
    @add_language_header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.show_title = false
    end
  end

  def add_language_scrolled_window
    @add_language_scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
      window.hscrollbar_policy = :never
    end
  end

  def add_language_box
    @add_language_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.valign = :center
      box.margin_start = 12
      box.margin_end = 12
      box.margin_top = 12
      box.margin_bottom = 12
    end
  end

  def illustration_box
    @illustration_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.halign = :center
    end
  end

  def illustration
    @illustration ||= Gtk::Picture.new.tap do |picture|
      picture.can_shrink = false
      picture.set_filename(ILLUSTRATION)
    end
  end

  def add_language_title
    @add_language_title ||= Gtk::Label.new(_("Add Language")).tap do |label|
      label.margin_top = 24
      label.add_css_class("title-1")
    end
  end

  def add_language_description
    @add_language_description ||= Gtk::Label.new(_(ADD_LANGUAGE_DESCRIPTION)).tap do |label|
      label.justify = :center
      label.wrap = true
      label.margin_top = 12
    end
  end

  def language_request_button
    @language_request_button ||= Gtk::Button.new.tap do |button|
      button.halign = :center
      button.margin_top = 24
      button.add_css_class("suggested-action")
      button.add_css_class("pill")
    end
  end

  def language_request_box
    @language_request_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.halign = :center
    end
  end

  def language_request_label
    @language_request_label ||= Gtk::Label.new(_("_Create Request")).tap do |label|
      label.use_underline = true
    end
  end

  def language_request_icon
    @language_request_icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = "external-link-symbolic"
      image.accessible_role = :presentation
    end
  end

  private

    # Upstream binds the scroll position to the header bar's `show-title` with
    # `sync_create`, so the binding also sets the initial state.
    def sync_header_title
      header_bar.show_title = scrolled_window.vadjustment.value.positive?
    end

    def build_choose_language_page
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scrolled_window

        header_bar.pack_start(add_language_button)

        scrolled_window.child = content_box

        content_box.tap do |box|
          box.append(title_label)
          box.append(search_clamp)
          box.append(stack)

          search_clamp.child = search_entry

          stack.tap do |pages|
            pages.add_named(list_box, "list")
            pages.add_named(search_results_box, "search-results")
            pages.add_named(no_results_box, "no-results")

            list_box.tap do |list|
              list.append(group_recent)
              list.append(group_other)
            end

            search_results_box.append(search_list)

            no_results_box.append(no_results_inner_box)

            no_results_inner_box.tap do |inner|
              inner.append(no_results_icon)
              inner.append(no_results_title)
              inner.append(no_results_description)
            end
          end
        end
      end
    end

    def build_add_language_page
      add_language_toolbar_view.tap do |view|
        view.add_top_bar(add_language_header_bar)
        view.content = add_language_scrolled_window

        add_language_scrolled_window.child = add_language_box

        add_language_box.tap do |box|
          box.append(illustration_box)
          box.append(add_language_title)
          box.append(add_language_description)
          box.append(language_request_button)

          illustration_box.append(illustration)

          language_request_button.tap do |button|
            button.child = language_request_box
            button.signal_connect("clicked") { launch_language_request }
          end

          language_request_box.tap do |inner|
            inner.append(language_request_label)
            inner.append(language_request_icon)
          end
        end
      end
    end

    # The current language first, then the remembered ones, then everything
    # else in alphabetical order.
    def populate_list
      current = current_language

      group_recent.add(LanguageRow.new(current).build)
      recent_languages.each { |language| group_recent.add(LanguageRow.new(language).build) }

      remaining = TextGeneration::Language::ALL - recent_languages - [current]
      remaining.sort_by(&:name).each { |language| group_other.add(LanguageRow.new(language).build) }
    end

    def update_search_state
      query = search_entry.text

      if query.empty?
        no_results_lock_height(true)
        stack.visible_child_name = "list"
      else
        show_search_results(search_for(query))
      end
    end

    def search_for(query)
      normalized = self.class.normalize(query)

      TextGeneration::Language::ALL
        .select { |language| self.class.normalize(language.name).include?(normalized) }
        .sort_by { |language| language.name.downcase }
    end

    def show_search_results(results)
      if results.empty?
        no_results_lock_height(false)
        stack.visible_child_name = "no-results"
      else
        search_list.remove_all
        results.each { |language| search_list.append(LanguageRow.new(language).build) }

        no_results_lock_height(true)
        stack.visible_child_name = "search-results"
      end
    end

    # Keeps the "No Matches" page from changing the dialog's height when it is
    # not the one showing.
    def no_results_lock_height(lock)
      no_results_box.height_request = -1
      no_results_box.valign = :fill

      if lock
        _found, bounds = no_results_box.compute_bounds(no_results_box)

        no_results_box.height_request = bounds.height.truncate
        no_results_box.valign = :start
      end
    end

    def launch_language_request
      Gtk::UriLauncher.new(LANGUAGE_REQUEST_URL).launch(root, nil)
    end

    # Upstream records the current language plus the previously remembered
    # ones, capped at three, when the dialog closes.
    def record_recent_languages
      current = @settings["text-language"]
      previous = @settings["recent-languages"].reject { |code| code == current }

      @settings["recent-languages"] = ([current] + previous).take(RECENT_LIMIT)
    end
end
