# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "style"
require_relative "typing_test_utils"

# ResultsView shows the words-per-minute and accuracy of a finished test,
# together with the test type, how long it really took, and the text language.
#
# Ported from upstream's src/widgets/results_view.blp and
# src/widgets/results_view.rs. Upstream is a GtkWidget subclass with a
# BinLayout that implements GtkOrientable and binds its own `orientation`
# property onto the two boxes inside it, with the spacing of the lower one
# mapped from it. The Ruby bindings cannot give a widget subclass a layout
# manager or new properties, so the single child the BinLayout would hold is
# the root widget here, and `orientation=` does what upstream's three property
# bindings do.
#
class ResultsView
  # The spacing of the test-info row in each orientation, upstream's
  # `transform_to` on the orientation binding.
  INFO_SPACING = { horizontal: 30, vertical: 18 }.freeze

  # The divider between the two numbers runs across the row, so it is flipped
  # with everything else. Upstream leaves it at the Blueprint default, which
  # its own screenshots show rendering as the perpendicular of the row.
  PERPENDICULAR = { horizontal: :vertical, vertical: :horizontal }.freeze

  COLUMN_WIDTH = 200

  def initialize
    @show_personal_best = false
  end

  def build
    root.tap do |box|
      box.append(wpm_accuracy_box)
      box.append(test_info_box)

      wpm_accuracy_box.tap do |row|
        row.append(wpm_column)
        row.append(separator)
        row.append(accuracy_column)

        wpm_column.tap do |column|
          column.append(wpm_row)
          column.append(wpm_caption)

          wpm_row.tap do |inner|
            inner.append(personal_best_balancer)
            inner.append(wpm_label)
            inner.append(personal_best)
          end
        end

        accuracy_column.tap do |column|
          column.append(accuracy_label)
          column.append(accuracy_caption)
        end
      end

      test_info_box.tap do |row|
        row.append(test_type_box)
        row.append(duration_box)
        row.append(language_box)

        test_type_box.tap do |info|
          info.append(test_type_icon)
          info.append(test_type_label)
        end

        duration_box.tap do |info|
          info.append(duration_icon)
          info.append(duration_label)
        end

        language_box.tap do |info|
          info.append(language_icon)
          info.append(language_label)
        end
      end

      self.orientation = :horizontal
    end
  end

  # Upstream's `show-personal-best` property, which the two images' `visible`
  # is bound to.
  def show_personal_best? = @show_personal_best

  def show_personal_best=(value)
    @show_personal_best = value
    personal_best.visible = value
    personal_best_balancer.visible = value
  end

  # Upstream's `orientation` property, which the breakpoint flips to vertical.
  def orientation=(value)
    wpm_accuracy_box.orientation = value
    test_info_box.orientation = value
    test_info_box.spacing = INFO_SPACING.fetch(value)
    separator.orientation = PERPENDICULAR.fetch(value)
  end

  # Upstream's `set_summary`.
  def set_summary(summary)
    wpm_label.label = format("%<wpm>.0f", wpm: summary.wpm.floor)

    # The percentage label format of the results page.
    accuracy_label.label = "#{(summary.accuracy * 100).floor}%"

    duration_label.label = self.class.human_readable_duration(summary.real_duration)
    test_type_label.label = self.class.test_type_string(summary.config)

    show_language(summary.config)
  end

  def self.test_type_string(config)
    if config.finite?
      "Custom"
    else
      config.difficulty
    end
  end

  def self.human_readable_duration(duration)
    total_seconds = duration.floor
    minutes = total_seconds / 60
    seconds = total_seconds % 60

    if minutes.positive? && seconds.positive?
      "#{minutes}m #{seconds}s"
    elsif minutes.positive?
      pluralized(minutes, "minute")
    else
      pluralized(seconds, "second")
    end
  end

  def self.pluralized(count, unit)
    if count == 1
      "#{count} #{unit}"
    else
      "#{count} #{unit}s"
    end
  end

  # Memoized widget methods

  def root
    @root ||= Gtk::Box.new(:vertical, 36).tap do |box|
      box.halign = :center
      box.margin_top = 12
      box.margin_bottom = 12
      box.add_css_class(Style::RESULTS_VIEW_CLASS)
    end
  end

  def wpm_accuracy_box = @wpm_accuracy_box ||= Gtk::Box.new(:horizontal, 12)

  def wpm_column
    @wpm_column ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.width_request = COLUMN_WIDTH
    end
  end

  def wpm_row
    @wpm_row ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.halign = :center
    end
  end

  # For the sake of alignment: an invisible twin of the personal-best arrow on
  # the other side of the number.
  def personal_best_balancer
    @personal_best_balancer ||= Gtk::Image.new.tap do |image|
      image.accessible_role = :presentation
      image.visible = false
    end
  end

  def wpm_label
    @wpm_label ||= Gtk::Label.new.tap do |label|
      label.add_css_class("key-number")
    end
  end

  def personal_best
    @personal_best ||= Gtk::Image.new.tap do |image|
      image.icon_name = "arrow3-up-symbolic"
      image.tooltip_text = "New Personal Best for Configuration"
      image.visible = false
      image.add_css_class("accent")
    end
  end

  def wpm_caption
    @wpm_caption ||= Gtk::Label.new("Words per Minute").tap do |label|
      label.add_css_class("dim-label")
    end
  end

  def separator = @separator ||= Gtk::Separator.new(:vertical)

  def accuracy_column
    @accuracy_column ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.width_request = COLUMN_WIDTH
    end
  end

  def accuracy_label
    @accuracy_label ||= Gtk::Label.new.tap do |label|
      label.add_css_class("key-number")
    end
  end

  def accuracy_caption
    @accuracy_caption ||= Gtk::Label.new("Accuracy").tap do |label|
      label.add_css_class("dim-label")
    end
  end

  def test_info_box
    @test_info_box ||= Gtk::Box.new(:horizontal, INFO_SPACING.fetch(:horizontal)).tap do |box|
      box.halign = :center
      box.homogeneous = true
    end
  end

  def test_type_box
    @test_type_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.halign = :center
      box.tooltip_text = "Test Type"
    end
  end

  def test_type_icon = @test_type_icon ||= info_icon("quotation-symbolic")

  def test_type_label = @test_type_label ||= Gtk::Label.new

  def duration_box
    @duration_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.halign = :center
      box.tooltip_text = "Test Duration"
    end
  end

  def duration_icon = @duration_icon ||= info_icon("timer-symbolic")

  def duration_label = @duration_label ||= Gtk::Label.new

  def language_box
    @language_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.halign = :center
      box.tooltip_text = "Text Language"
    end
  end

  def language_icon = @language_icon ||= info_icon("language-symbolic")

  def language_label = @language_label ||= Gtk::Label.new

  private

    def info_icon(name)
      Gtk::Image.new.tap do |image|
        image.icon_name = name
        image.accessible_role = :presentation
      end
    end

    # A custom-text test has no language to report, so the whole group goes
    # away rather than showing an empty label.
    def show_language(config)
      if config.finite?
        language_box.visible = false
      else
        language_box.visible = true
        language_label.label = config.language.name
      end
    end
end
