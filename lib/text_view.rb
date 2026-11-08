# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "style"
require_relative "text_utils"
require_relative "text_view_colors"

# TextView is the typing surface: it shows the text to type, colours it as the
# user goes, draws its own caret, scrolls itself, and is the thing that knows
# when a test has started.
#
# Ported from upstream's src/widgets/text_view.blp, src/widgets/text_view.rs
# and the four files under src/widgets/text_view/ (input, caret, scrolling,
# accessibility); the colouring lives in text_view_colors.rb.
#
# Upstream is a GtkWidget subclass that overrides `measure` (to pin its height
# to three lines), `size_allocate` and `snapshot` (to draw the caret with a
# Gsk path on top of the child text view). The Ruby bindings do not let a
# GtkWidget subclass override those virtual functions at all — a subclass's
# `measure`/`snapshot` methods are simply never called — so this port composes
# the same thing out of stock widgets instead:
#
#   * a GtkOverlay as the root, carrying the focus, the input controllers and
#     the `kp-text-view` style class that upstream's CSS name stands for;
#   * a GtkScrolledWindow with an external vertical scrollbar, which pins the
#     height to three lines the way upstream's `measure` does, clips the text,
#     and owns the vertical adjustment the scroll animation drives;
#   * a GtkDrawingArea in the overlay, which draws the caret with Cairo where
#     upstream strokes a Gsk path in `snapshot`.
#
# The caret animations also differ in mechanism: upstream animates the widget's
# own `caret-x` and `caret-y` properties with AdwPropertyAnimationTarget, which
# needs real GObject properties. A plain Ruby object has none, so the two caret
# animations use AdwCallbackAnimationTarget and write the value back into this
# object. The scroll animation still targets a real property, the adjustment's
# `value`, exactly as upstream does.
#
# Upstream's accessibility.rs republishes the word being typed as the widget's
# accessible label on every word boundary, via
# `update_property(&[Property::Label(word)])`. `Gtk::Accessible#update_property`
# raises NotImplementedError in these bindings, which have no converter for an
# array of accessible properties, so that specific call cannot be made from
# Ruby. The behaviour it exists for — a screen reader speaking the current
# word as a test is typed — is restored here with `Gtk::Accessible#announce`
# instead (GTK 4.14+; both bindings expose it), which speaks a one-off
# AT-SPI announcement rather than republishing a static property, and reaches
# the same screen-reader user upstream's call does. The accessible roles the
# Blueprint sets — text_box on the root, presentation on the inner text view —
# are set here, and `current_word` exposes the word that gets announced.
#
class TextView
  include TextViewColors

  # This needs to mirror the `line-height` value in data/style.css
  LINE_HEIGHT = 50

  # How many lines of text are visible at once. Upstream's `measure` reports
  # LINE_HEIGHT * 3 for both the minimum and the natural height.
  VISIBLE_LINES = 3

  CARET_ANIMATION_DURATION = 150
  SCROLL_ANIMATION_DURATION = 300

  # How far the scroll position has to move before the animation is worth
  # playing, in pixels.
  SCROLL_CHANGE_THRESHOLD = 10

  attr_reader :original_text, :typed_text, :keystrokes
  attr_accessor :accepts_input

  # `on_running_changed` stands in for upstream's `notify::running`, and
  # `on_typed_text_changed` for its `typed-text-changed` signal. Both are
  # optional, so the widget can be driven on its own in a test.
  def initialize(on_running_changed: nil, on_typed_text_changed: nil)
    @on_running_changed = on_running_changed
    @on_typed_text_changed = on_typed_text_changed

    @original_text = ""
    @typed_text = ""
    @previous_preedit = ""
    @keystrokes = []
    @running = false
    @accepts_input = false
    @caret_x = 0.0
    @caret_y = 0.0
    @caret_height = 0.0
    @caret_rgb = [0.0, 0.0, 0.0]
  end

  def build
    root.tap do |overlay|
      overlay.child = scrolled_window
      overlay.add_overlay(caret_area)

      scrolled_window.child = text_view

      caret_area.set_draw_func { |_area, context, _width, _height| draw_caret(context) }

      overlay.signal_connect("notify::has-focus") do
        focus_changed
      end

      vadjustment.signal_connect("changed") { allocation_changed }

      setup_input_handling
      setup_color_scheme
      update_scroll_position(true)
      update_caret_position(true)
    end
  end

  # Upstream's `running` property. The text view sets it the moment the first
  # character is committed, which is what starts a test.
  def running? = @running

  def running=(value)
    changed = @running != value
    @running = value

    if changed
      @on_running_changed&.call(self)
    end
  end

  def original_text=(text)
    @original_text = text
    buffer.text = TextUtils.insert_replacements(text)
    compare_and_update_colors
    update_caret_position(true)
    update_scroll_position(true)
  end

  def push_original_text(text)
    @original_text += text
    buffer.insert(buffer.end_iter, TextUtils.insert_replacements(text))
    compare_and_update_colors
  end

  def typed_text=(text)
    @typed_text = text
    typed_text_changed(:replacement)
    input_context.reset
  end

  def original_grapheme_count = TextUtils.graphemes(@original_text).length

  def typed_grapheme_count = TextUtils.graphemes(@typed_text).length

  def last_grapheme_state
    comparison = TextUtils.validate_with_replacements(@original_text, @typed_text, 0)

    comparison.last&.first || TextUtils::UNFINISHED
  end

  # Returns [current word, total word count].
  def progress
    [
      TextUtils.current_word(@original_text, typed_grapheme_count),
      TextUtils.unicode_words(@original_text).length,
    ]
  end

  def reset
    self.original_text = ""
    self.typed_text = ""
    self.running = false

    scroll_animation.skip
    caret_x_animation.skip
    caret_y_animation.skip
    @keystrokes.clear
  end

  def focused? = root.has_focus?

  def grab_focus = root.grab_focus

  def add_css_class(name) = root.add_css_class(name)

  def remove_css_class(name) = root.remove_css_class(name)

  # The word upstream's accessibility.rs would announce: the word of the
  # original text the caret currently sits in.
  def current_word
    typed_length = @typed_text.chars.length
    start = word_start_before(typed_length)

    @original_text.chars.drop(start).take_while { |char| !char.match?(/\s/) }.join
  end

  # Memoized widget methods

  def root
    @root ||= Gtk::Overlay.new.tap do |overlay|
      overlay.focusable = true
      overlay.overflow = :hidden
      overlay.valign = :center
      overlay.margin_start = 12
      overlay.margin_end = 12
      overlay.height_request = LINE_HEIGHT * VISIBLE_LINES
      overlay.accessible_role = :text_box
      overlay.add_css_class(Style::TEXT_VIEW_CLASS)
    end
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
      window.set_policy(:never, :external)
      window.propagate_natural_height = false
      window.height_request = LINE_HEIGHT * VISIBLE_LINES
    end
  end

  def text_view
    @text_view ||= Gtk::TextView.new.tap do |view|
      view.monospace = true
      view.focusable = false
      view.editable = false
      view.cursor_visible = false
      view.wrap_mode = :word_char
      view.can_target = false
      view.bottom_margin = LINE_HEIGHT
      view.accessible_role = :presentation
    end
  end

  def caret_area
    @caret_area ||= Gtk::DrawingArea.new.tap do |area|
      area.can_target = false
      area.accessible_role = :presentation
    end
  end

  def buffer = text_view.buffer

  def vadjustment = scrolled_window.vadjustment

  def input_context
    @input_context ||= Gtk::IMMulticontext.new.tap do |context|
      context.input_hints = Gtk::InputHints::NO_SPELLCHECK
    end
  end

  def key_controller
    @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
      controller.im_context = input_context
    end
  end

  def click_gesture = @click_gesture ||= Gtk::GestureClick.new

  def scroll_animation
    @scroll_animation ||= Adwaita::TimedAnimation.new(
      text_view,
      0.0,
      0.0,
      SCROLL_ANIMATION_DURATION,
      Adwaita::PropertyAnimationTarget.new(vadjustment, "value"),
    )
  end

  def caret_x_animation
    @caret_x_animation ||= Adwaita::TimedAnimation.new(
      root,
      0.0,
      0.0,
      CARET_ANIMATION_DURATION,
      Adwaita::CallbackAnimationTarget.new { |value| set_caret_x(value) },
    )
  end

  def caret_y_animation
    @caret_y_animation ||= Adwaita::TimedAnimation.new(
      root,
      0.0,
      0.0,
      CARET_ANIMATION_DURATION,
      Adwaita::CallbackAnimationTarget.new { |value| set_caret_y(value) },
    )
  end

  private

    # Input handling — upstream's src/widgets/text_view/input.rs

    def setup_input_handling
      input_context.set_client_widget(root)

      input_context.signal_connect("commit") { |_context, text| commit_text(text) }
      input_context.signal_connect("preedit-changed") { preedit_changed }
      input_context.signal_connect("retrieve-surrounding") { |context| retrieve_surrounding(context) }
      input_context.signal_connect("delete-surrounding") { |_context, offset, _count| delete_surrounding(offset) }

      click_gesture.signal_connect("released") do |controller, _presses, _x, _y|
        input_context.activate_osk(controller.current_event)
      end

      key_controller.signal_connect("key-pressed") do |_controller, keyval, _keycode, state|
        key_pressed(keyval, state)
      end

      root.add_controller(click_gesture)
      root.add_controller(key_controller)
    end

    def commit_text(text)
      if @accepts_input
        self.running = true
        push_typed_text(text)
      end
    end

    def preedit_changed
      preedit = preedit_string

      if preedit != @previous_preedit && @accepts_input
        self.running = true
        @previous_preedit = preedit
        typed_text_changed(:addition)
      end
    end

    def retrieve_surrounding(context)
      context.set_surrounding_with_selection(@typed_text, @typed_text.bytesize, @typed_text.bytesize)
      true
    end

    # The cursor will always be at the end of the typed text, so we can safely
    # just pop the {offset} last characters
    def delete_surrounding(offset)
      pop_typed_text(offset.abs)
      true
    end

    def key_pressed(keyval, state)
      if @typed_text.empty? || !@accepts_input
        false
      else
        handle_editing_key(keyval, state)
      end
    end

    def handle_editing_key(keyval, state)
      control = state.to_i.anybits?(Gdk::ModifierType::CONTROL_MASK.to_i)

      case keyval
      when Gdk::Keyval::KEY_BackSpace then backspace(control)
      when Gdk::Keyval::KEY_Return then commit_newline
      else false
      end
    end

    def backspace(control)
      if control
        pop_typed_text_word
      else
        pop_typed_text(1)
      end

      true
    end

    def commit_newline
      commit_text("\n")
      true
    end

    def push_typed_text(text)
      @typed_text += text
      @typed_text = fold_completed_alias(@typed_text)

      typed_text_changed(:addition)
    end

    # When the typed text ends in a complete alias — "ae" where the original
    # has "æ" — the alias is replaced with the letter it stands for.
    def fold_completed_alias(typed)
      found = TextUtils.end_alias(@original_text, typed)

      if found && found.last
        letter, typed_so_far, = found
        kept = typed.chars.length - typed_so_far.chars.length
        typed.chars.take(kept).join + letter
      else
        typed
      end
    end

    def pop_typed_text(graphemes)
      @typed_text = TextUtils.pop_graphemes(@typed_text, graphemes)

      typed_text_changed(:removal)
    end

    def pop_typed_text_word
      @typed_text = TextUtils.pop_word(@original_text, @typed_text)

      typed_text_changed(:removal)
    end

    def typed_text_changed(change)
      comparison = TextUtils.validate_with_replacements(@original_text, @typed_text, preedit_grapheme_count)

      record_keystroke(change, comparison)

      update_colors(comparison)
      update_caret_position(!@running)
      update_scroll_position(!@running)
      announce_current_word_at_boundary

      @on_typed_text_changed&.call(self)
    end

    def record_keystroke(change, comparison)
      if change == :addition
        state = comparison.last&.first || TextUtils::UNFINISHED
        @keystrokes << [Process.clock_gettime(Process::CLOCK_MONOTONIC), state != TextUtils::MISTAKE]
      elsif change == :removal
        # If text is removed, it's always a "correct" stroke
        @keystrokes << [Process.clock_gettime(Process::CLOCK_MONOTONIC), true]
      end
    end

    # Upstream does this from `size_allocate`: once the text has been laid out
    # at a new size, where the caret goes, how far the view is scrolled and
    # which lines are worth colouring all change, and none of them can be
    # worked out before the lines exist. A widget subclass cannot override
    # `size_allocate` here, so the adjustment's `changed` signal — which the
    # text view emits whenever its laid-out size or the space it has for it
    # moves — is what stands in for it.
    #
    # Applying tags can nudge the laid-out height, so the signal can come back
    # around; the flag keeps that from recurring.
    def allocation_changed
      if !@laying_out
        @laying_out = true

        begin
          update_scroll_position(true)
          update_caret_position(true)
          compare_and_update_colors
        ensure
          @laying_out = false
        end
      end
    end

    def focus_changed
      if root.has_focus?
        input_context.focus_in
      else
        input_context.focus_out
      end

      update_scroll_position(true)
    end

    def preedit_string = input_context.preedit_string.first.to_s

    def preedit_grapheme_count = TextUtils.graphemes(preedit_string).length

    # Caret — upstream's src/widgets/text_view/caret.rs

    def set_caret_x(value)
      @caret_x = value
      caret_area.queue_draw
    end

    def set_caret_y(value)
      @caret_y = value
      caret_area.queue_draw
    end

    def draw_caret(context)
      red, green, blue = @caret_rgb

      context.set_source_rgb(red, green, blue)
      context.set_line_width(1.0)
      context.move_to(@caret_x, @caret_y + @caret_height)
      context.line_to(@caret_x, @caret_y)
      context.stroke
    end

    # The iter in the buffer the caret sits at, replacements and half-typed
    # aliases accounted for.
    def caret_iter
      line, index = TextUtils.line_offset_with_replacements(@original_text, @typed_text, preedit_grapheme_count)

      buffer.get_iter_at(line: line, index: index)
    end

    # Calculates where the caret currently should be, and runs an animation to
    # get it there. If `force` is true, the change happens unconditionally and
    # without an animation.
    def update_caret_position(force)
      iter = caret_iter
      strong, = text_view.get_cursor_locations(iter)
      @caret_height = strong.height

      target_x = caret_x_for(iter, strong)
      target_y = caret_y_for

      if force
        set_caret_x(target_x.to_f)
        set_caret_y(target_y.to_f)
      else
        animate_caret(target_x, target_y)
        input_context.set_cursor_location(
          Gdk::Rectangle.new(
            target_x,
            target_y,
            1,
            strong.height,
          ),
        )
      end
    end

    def caret_x_for(iter, strong)
      window_x, = text_view.buffer_to_window_coords(Gtk::TextWindowType::WIDGET, strong.x, strong.y)

      if text_view.starts_display_line(iter)
        line_edge_x
      else
        window_x
      end
    end

    # At the start of a display line the caret sits just outside the text, on
    # whichever side the line begins.
    def line_edge_x
      width = root.width

      case [@running, line_rtl?]
      when [false, false] then -2
      when [false, true] then width + 2
      when [true, false] then 1
      else width - 1
      end
    end

    def line_rtl?
      cursor = caret_iter
      cursor.line_index = 0

      text_view.get_iter_location(cursor).x > 0
    end

    def caret_y_for
      cursor = caret_iter

      # If we can't move the iter backwards one display line, that must mean
      # we're at the first one
      if text_view.backward_display_line(cursor)
        text_view.get_cursor_locations(second_display_line_iter).last.y
      else
        text_view.get_cursor_locations(buffer.start_iter).last.y
      end
    end

    def second_display_line_iter
      buffer.start_iter.tap do |cursor|
        text_view.forward_display_line(cursor)
      end
    end

    def animate_caret(target_x, target_y)
      caret_x_animation.tap do |animation|
        animation.value_from = @caret_x
        animation.value_to = target_x.to_f
        animation.play
      end

      caret_y_animation.tap do |animation|
        animation.value_from = @caret_y
        animation.value_to = target_y.to_f
        animation.play
      end
    end

    # Scrolling — upstream's src/widgets/text_view/scrolling.rs

    # Updates the scroll position according to the text view and the length of
    # the typed text so far. If `force` is true, the change is made
    # unconditionally and without an animation.
    def update_scroll_position(force)
      target = scroll_target

      if force
        vadjustment.value = target
      else
        play_scroll_animation(target)
      end
    end

    def scroll_target
      if snap_to_top?
        0.0
      else
        location = text_view.get_iter_location(caret_iter)
        [(location.y + (location.height / 2)) - (root.height / 2), 0].max.to_f
      end
    end

    # If we can't move the iter backwards two lines, that must mean that we're
    # at line 1 or 2. To prevent any form of slight scrolling when moving from
    # line 1 to 2, we snap the text view to the top in that case. This is
    # necessary because some scripts can have very tall letters.
    def snap_to_top?
      cursor = caret_iter
      text_view.backward_display_line(cursor)

      !text_view.backward_display_line(cursor) || @typed_text.empty?
    end

    def play_scroll_animation(target)
      line_has_changed = (scroll_animation.value_to - target).abs > SCROLL_CHANGE_THRESHOLD

      if line_has_changed
        scroll_animation.value_from = vadjustment.value
        scroll_animation.value_to = target
        scroll_animation.play
      end
    end

    # Accessibility — upstream's src/widgets/text_view/accessibility.rs

    # Upstream's `update_accessible_state`: speaks the word currently being
    # typed to a screen reader, the moment the caret lands on its first
    # character. `root.announce` is this binding's stand-in for upstream's
    # `update_property(&[Property::Label(word)])` — see the class comment.
    def announce_current_word_at_boundary
      typed_length = @typed_text.chars.length
      start = word_start_before(typed_length)

      if typed_length == start
        root.announce(current_word, Gtk::AccessibleAnnouncementPriority::MEDIUM)
      end
    end

    # The character index the word containing `position` starts at.
    def word_start_before(position)
      @original_text.chars.take(position).each_with_index.reduce(0) do |start, (char, index)|
        if char.match?(/\s/)
          index + 1
        else
          start
        end
      end
    end
end
