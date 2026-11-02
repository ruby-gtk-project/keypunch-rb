# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "text_utils"

# TextViewColors colours the typing surface: grey for text that has not been
# reached, foreground for text typed correctly, red for mistakes, and an
# underline for a grapheme that is still being composed.
#
# Ported from upstream's src/widgets/text_view/colors.rs. Upstream creates
# sixteen GtkTextTags up front — four states across four themes (light, light
# high contrast, dark, dark high contrast) — and switches between them when
# AdwStyleManager reports a change, rather than editing tag colours in place.
# The colour values are upstream's, and its comment explains where they came
# from: a screenshot of the Adwaita Demo app's "Style classes" page, picked
# with a colour picker and divided by 256.
#
# Mixed into TextView, which owns the buffer and the typed/original text.
#
module TextViewColors
  # Each theme's four tags are named after the grapheme state they colour —
  # untyped, unfinished, typed, mistake — plus the theme's suffix.
  THEMES = {
    light:    {
      suffix:     "",
      untyped:    [0.547, 0.547, 0.547],
      typed:      [0.180, 0.180, 0.180],
      mistake_fg: [0.875, 0.105, 0.141],
      mistake_bg: [0.965, 0.891, 0.895],
      caret:      [0.180, 0.180, 0.180],
    },
    light_hc: {
      suffix:     "-hc",
      untyped:    [0.380, 0.380, 0.380],
      typed:      [0.0, 0.0, 0.0],
      mistake_fg: [0.976, 0.976, 0.976],
      mistake_bg: [0.875, 0.105, 0.141],
      caret:      [0.180, 0.180, 0.180],
    },
    dark:     {
      suffix:     "-dark",
      untyped:    [0.484, 0.484, 0.484],
      typed:      [1.0, 1.0, 1.0],
      mistake_fg: [0.961, 0.379, 0.316],
      mistake_bg: [0.223, 0.164, 0.156],
      caret:      [1.0, 1.0, 1.0],
    },
    dark_hc:  {
      suffix:     "-dark-hc",
      untyped:    [0.600, 0.600, 0.600],
      typed:      [1.0, 1.0, 1.0],
      mistake_fg: [0.140, 0.140, 0.140],
      mistake_bg: [0.961, 0.379, 0.316],
      caret:      [1.0, 1.0, 1.0],
    },
  }.freeze

  # How many display lines above and below the active one get coloured. Just
  # enough to account for the scrolling animation in all cases.
  COLORED_LINE_REACH = 3

  def setup_color_scheme
    THEMES.each_value { |theme| create_theme_tags(theme) }

    style_manager.signal_connect("notify::dark") { compare_and_update_colors }
    style_manager.signal_connect("notify::high-contrast") { compare_and_update_colors }

    compare_and_update_colors
  end

  # Convenience function to generate a comparison and update the colors.
  def compare_and_update_colors
    update_colors(
      TextUtils.validate_with_replacements(@original_text, @typed_text, preedit_grapheme_count),
    )
  end

  # Comparisons (lists of right/wrong letters) are slightly expensive to
  # generate, so this takes one as a parameter instead of generating one
  # internally. That allows reusing a comparison elsewhere in the keypress
  # pipeline.
  def update_colors(comparison)
    theme = THEMES.fetch(current_theme)

    # All tags are removed and reapplied on each recoloring for the sake of
    # keeping things simple
    buffer.remove_all_tags(buffer.start_iter, buffer.end_iter)

    typed_iter = caret_iter

    color_typed_range(comparison, theme, typed_iter)
    color_untyped_range(theme, typed_iter)

    @caret_rgb = theme.fetch(:caret)
  end

  # The theme in force right now, as a key of THEMES.
  def current_theme
    if style_manager.dark?
      dark_theme
    else
      light_theme
    end
  end

  private

    def style_manager = Adwaita::StyleManager.default

    def dark_theme
      if style_manager.high_contrast?
        :dark_hc
      else
        :dark
      end
    end

    def light_theme
      if style_manager.high_contrast?
        :light_hc
      else
        :light
      end
    end

    def create_theme_tags(theme)
      suffix = theme.fetch(:suffix)

      tag("untyped#{suffix}").foreground_rgba = rgba(theme.fetch(:untyped))

      tag("unfinished#{suffix}").tap do |unfinished|
        unfinished.foreground_rgba = rgba(theme.fetch(:untyped))
        unfinished.underline = Pango::Underline::LOW
      end

      tag("typed#{suffix}").foreground_rgba = rgba(theme.fetch(:typed))

      tag("mistake#{suffix}").tap do |mistake|
        mistake.foreground_rgba = rgba(theme.fetch(:mistake_fg))
        mistake.background_rgba = rgba(theme.fetch(:mistake_bg))
      end
    end

    def tag(name) = buffer.create_tag(name, {})

    def rgba(components)
      red, green, blue = components
      Gdk::RGBA.new(
        red,
        green,
        blue,
        1.0,
      )
    end

    # The name of the tag a grapheme state maps to in the current theme.
    def tag_name(state, theme)
      case state
      when TextUtils::CORRECT then "typed#{theme.fetch(:suffix)}"
      when TextUtils::MISTAKE then "mistake#{theme.fetch(:suffix)}"
      else "unfinished#{theme.fetch(:suffix)}"
      end
    end

    # Colours everything the comparison covers, starting a few display lines
    # above the active one so that as little text as possible is touched.
    def color_typed_range(comparison, theme, typed_iter)
      comparison.drop(color_start_offset).each do |state, line, start_index, end_index|
        start_iter = buffer.get_iter_at(line: line, index: start_index)
        end_iter = buffer.get_iter_at(line: line, index: end_index)

        # Avoid applying the tag to line breaks, which leads to some weird side
        # effects in the text view. Might be a GTK bug.
        if !start_iter.ends_line
          buffer.apply_tag_by_name(tag_name(state, theme), start_iter, end_iter)
        end
      end
    end

    # Colours the text the user has not reached yet, ending a few display lines
    # below the active one.
    def color_untyped_range(theme, typed_iter)
      name = "untyped#{theme.fetch(:suffix)}"

      (typed_iter.offset...color_end_offset).each do |offset|
        start_iter = buffer.get_iter_at(offset: offset)

        if !start_iter.ends_line
          buffer.apply_tag_by_name(name, start_iter, buffer.get_iter_at(offset: offset + 1))
        end
      end
    end

    def color_start_offset
      cursor = caret_iter

      COLORED_LINE_REACH.times { text_view.backward_display_line(cursor) }
      text_view.backward_display_line_start(cursor)

      TextUtils.graphemes(buffer.get_text(buffer.start_iter, cursor, true)).length
    end

    def color_end_offset
      cursor = caret_iter

      COLORED_LINE_REACH.times { text_view.forward_display_line(cursor) }
      text_view.forward_display_line_end(cursor)

      cursor.offset
    end
end
