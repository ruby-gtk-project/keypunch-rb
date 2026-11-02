# frozen_string_literal: true

# TextUtils holds the grapheme-level comparison between the text the user is
# supposed to type and what they have actually typed so far.
#
# Ported from upstream's src/text_utils.rs. Upstream leans on the
# `unicode_segmentation` crate for grapheme clusters, words and word bounds.
# Ruby's regexp engine knows `\X` (an extended grapheme cluster) natively, so
# graphemes come from `scan(/\X/)`; words and word bounds are scanned with the
# patterns in WORD_BOUND_PATTERN below, which follow the UAX #29 rules upstream
# relies on (letters and the marks that attach to them stay together, numbers
# keep their separators, and a run of horizontal whitespace is one segment).
#
# The byte offsets the comparison returns are byte offsets *within a line*,
# because that is what Gtk::TextBuffer#get_iter_at(line:, index:) wants — the
# same reason upstream returns byte indices rather than grapheme counts.
#
module TextUtils
  # String replacements for when text is displayed in the text view
  REPLACEMENTS = [
    ["\n", "↲\n"], # Visually indicate enter
  ].freeze

  # Accepted alternate ways to type out certain characters
  ALIASES = [
    ["\u00C6", "Ae"], # Æ — the French use this to type out æ
    ["\u00E6", "ae"], # æ
    ["\u0152", "Oe"], # Œ — the French use this to type out œ
    ["\u0153", "oe"], # œ
    ["\u025B", "\u03B5"], # ɛ and ε, often used interchangeably due to lack of
    ["\u03B5", "\u025B"], # keyboard standardization, especially for Kabyle
    ["\u00AB", "\""], # « — guillemet quotation marks
    ["\u00BB", "\""], # »
    ["\u201E", "\""], # „ — typographic quotation marks
    ["\u201D", "\""], # ”
    ["\u201C", "\""], # “
    ["\u2019", "'"], # ’ — typographic apostrophe
    ["\u00A0", "\u0020"], # Non-breaking spaces made typable as regular ones
    ["\u202F", "\u0020"],
    ["\u0020", "\u00A0"], # Vice versa
    ["\u0020", "\u202F"],
  ].freeze

  # The largest grapheme count of any current alias, kept track of manually for
  # performance reasons. If this is too large, nothing will happen. If it's too
  # small, larger aliases won't be recognized.
  ALIAS_MAX_SIZE = 2

  # The three states a grapheme of the original text can be in. Upstream's
  # `GraphemeState` enum.
  CORRECT = :correct
  UNFINISHED = :unfinished
  MISTAKE = :mistake

  # One UAX #29 word-bound segment: a letter run with its combining marks and
  # intra-word apostrophes, a number run with its separators, a run of
  # horizontal whitespace, or any single remaining grapheme.
  WORD_BOUND_PATTERN = /
    [[:alpha:]][[:alpha:]\p{Mn}\p{Mc}\p{Pc}]*(?:['’][[:alpha:]]+)*
    | [[:digit:]][[:digit:]]*(?:[.,][[:digit:]]+)*
    | [ \t]+
    | \X
  /x

  module_function

  # Splits a string into extended grapheme clusters.
  def graphemes(string) = string.scan(/\X/)

  # Upstream's `split_inclusive("\n")`: each line keeps its trailing newline.
  def lines_inclusive(string) = string.each_line.to_a

  # Upstream's `split_word_bounds`: every segment of the string, words and
  # whitespace and punctuation alike, in order.
  def word_bounds(string) = string.scan(WORD_BOUND_PATTERN)

  # Upstream's `unicode_words`: only the segments that are actual words.
  def unicode_words(string) = word_bounds(string).select { |segment| segment.match?(/[[:alnum:]]/) }

  # Trims every line of a custom text and ensures exactly one newline between
  # them, with none trailing.
  def process_custom_text(string) = string.lines.map(&:strip).join("\n")

  # Replaces whitespace that would otherwise be invisible with its marker.
  def insert_replacements(string)
    REPLACEMENTS.reduce(string) do |result, (original, replacement)|
      result.gsub(original, replacement)
    end
  end

  # Gets the corresponding whitespace marker of a grapheme, if any.
  def replacement(string)
    REPLACEMENTS.find { |whitespace, _| whitespace == string }&.last
  end

  # Gets the alternate way of typing a grapheme, if there is one.
  def alias_for(string)
    ALIASES.find { |letter, _| letter == string }&.last
  end

  # Finds out if there is a full or partial alias (alternate typing method)
  # being typed out now, with a corresponding character at that position in the
  # original text.
  #
  # Returns [letter, typed_so_far, complete?] or nil.
  def end_alias(original, typed)
    typed_graphemes = graphemes(typed)
    original_graphemes = graphemes(original)

    # Any current valid letter is in `original[typed-ALIAS_MAX_SIZE..typed]`
    skipped = [typed_graphemes.length - ALIAS_MAX_SIZE, 0].max

    candidates = original_graphemes
      .each_with_index
      .drop(skipped)
      .take(ALIAS_MAX_SIZE)
      .reverse
      .filter_map { |grapheme, position| alias_candidate(position, grapheme) }

    candidates
      .lazy
      .filter_map { |candidate| alias_match(typed_graphemes, candidate) }
      .first
  end

  # The returned tuples contain a state, as well as the line number and
  # start/end byte indices within that line the state applies to. Replacements
  # are accounted for.
  def validate_with_replacements(original, typed, unfinished_letter_length)
    effective = effective_typed(original, typed, unfinished_letter_length)
    typed_graphemes = graphemes(effective[:typed])
    last_typed_offset = [typed_graphemes.length - 1, 0].max
    sequence = typed_graphemes + Array.new(effective[:unfinished_length], " ")

    [].tap do |result|
      accumulator_line = 0
      accumulated_offset = 0

      original_cells(original).each_with_index do |cell, offset|
        typed_grapheme = sequence[offset]

        if typed_grapheme.nil?
          break
        end

        if accumulator_line != cell[:line]
          accumulator_line = cell[:line]
          accumulated_offset = 0
        end

        state = grapheme_state(
          cell[:grapheme],
          typed_grapheme,
          offset:            offset,
          last_typed_offset: last_typed_offset,
          overshoot:         effective[:overshoot],
        )

        marker = replacement(cell[:grapheme])

        if marker
          index = cell[:index] + accumulated_offset
          graphemes(marker).each do |marker_grapheme|
            result << [state, cell[:line], index, index + marker_grapheme.bytesize]
            index += marker_grapheme.bytesize
          end
          accumulated_offset += (marker.bytesize - cell[:grapheme].bytesize).abs
        else
          index = cell[:index] + accumulated_offset
          result << [state, cell[:line], index, index + cell[:grapheme].bytesize]
        end
      end
    end
  end

  # Get the line number and byte offset within that line of the caret, taking
  # replacements and aliases into account.
  def line_offset_with_replacements(original, typed, unfinished_letter_length)
    grapheme_index = caret_grapheme_index(original, typed, unfinished_letter_length)
    original_graphemes = graphemes(original)
    lines = lines_inclusive(original).map { |line| graphemes(line).length }

    line_number = line_of_grapheme(lines, grapheme_index)
    line_start = lines.take(line_number).sum

    byte_offset = original_graphemes
      .take(grapheme_index)
      .drop(line_start)
      .sum { |grapheme| replacement(grapheme)&.bytesize || grapheme.bytesize }

    [line_number, byte_offset]
  end

  # Removes the last `count` graphemes from a string, returning the shortened
  # string. Upstream mutates a `&mut String` in place; a Ruby string literal is
  # frozen, so the shortened copy is returned instead.
  def pop_graphemes(string, count)
    kept = graphemes(string)
    kept[0, [kept.length - count, 0].max].join
  end

  # Adjusts the typed text length so the caret is moved to the beginning of the
  # current word in the original text.
  def pop_word(original, typed)
    cutoff = original.chars.take(typed.chars.length).join
    last_segment = word_bounds(cutoff).last

    if last_segment.nil?
      typed
    else
      typed.chars[0, [typed.chars.length - last_segment.chars.length, 0].max].join
    end
  end

  # The one-based index of the word the caret currently sits in.
  def current_word(original, typed_grapheme_count)
    unicode_words(graphemes(original).take(typed_grapheme_count).join).length
  end

  # Words per minute, counting a word as five correctly typed characters.
  def calculate_wpm(duration, original, typed)
    minutes = duration / 60.0
    correct = original.chars.zip(typed.chars).count { |original_char, typed_char| original_char == typed_char }

    (correct / 5.0) / minutes
  end

  # Every grapheme of the original text, with the line it is on and its byte
  # offset within that line.
  def original_cells(original)
    [].tap do |cells|
      lines_inclusive(original).each_with_index do |line, line_number|
        index = 0

        graphemes(line).each do |grapheme|
          cells << { grapheme: grapheme, line: line_number, index: index }
          index += grapheme.bytesize
        end
      end
    end
  end

  # The typed text, unfinished letter length and overshoot to compare with,
  # with a half-typed alias folded back into the letter it stands for.
  def effective_typed(original, typed, unfinished_letter_length)
    found = end_alias(original, typed)

    if found && !found.last
      letter, typed_so_far, = found
      partial_alias_state(typed, letter, typed_so_far)
    elsif unfinished_letter_length.positive?
      {
        typed:             typed,
        unfinished_length: unfinished_letter_length,
        overshoot:         unfinished_letter_length,
      }
    else
      {
        typed:             typed,
        unfinished_length: unfinished_letter_length,
        overshoot:         0,
      }
    end
  end

  def partial_alias_state(typed, letter, typed_so_far)
    kept = graphemes(typed)
    alias_length = graphemes(typed_so_far).length

    {
      typed:             kept[0, [kept.length - alias_length, 0].max].join,
      unfinished_length: graphemes(letter).length,
      overshoot:         alias_length,
    }
  end

  # The position in the original text of a grapheme that has an alias, with the
  # grapheme and the alias itself. nil when the grapheme has no alias.
  def alias_candidate(position, grapheme)
    found = alias_for(grapheme)

    if found
      [position, grapheme, found]
    end
  end

  def alias_match(typed_graphemes, candidate)
    position, letter, expected = candidate
    typed_so_far = typed_graphemes.drop(position).join

    if typed_so_far.empty?
      nil
    elsif expected == typed_so_far
      [letter, typed_so_far, true]
    elsif expected.start_with?(typed_so_far)
      [letter, typed_so_far, false]
    end
  end

  def grapheme_state(original_grapheme, typed_grapheme, offset:, last_typed_offset:, overshoot:)
    potentially_unfinished = (original_grapheme.start_with?(typed_grapheme) && offset == last_typed_offset) ||
      offset + overshoot > last_typed_offset

    if original_grapheme == typed_grapheme
      CORRECT
    elsif potentially_unfinished
      UNFINISHED
    else
      MISTAKE
    end
  end

  def caret_grapheme_index(original, typed, unfinished_letter_length)
    typed_count = graphemes(typed).length
    found = end_alias(original, typed)

    if found
      letter, typed_so_far, = found
      typed_count - graphemes(typed_so_far).length + graphemes(letter).length
    elsif unfinished_letter_length.positive?
      typed_count + unfinished_letter_length
    else
      typed_count
    end
  end

  def line_of_grapheme(line_lengths, grapheme_index)
    remaining = grapheme_index
    found = nil

    line_lengths.each_with_index do |length, line_number|
      if found.nil? && remaining < length
        found = line_number
      end
      remaining -= length
    end

    found || 0
  end
end
