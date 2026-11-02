# frozen_string_literal: true

require_relative "text_utils"

# TextGeneration builds the text a generated typing test is taken from.
#
# Ported from upstream's src/text_generation.rs, together with the word lists
# in data/word_lists. Upstream embeds the lists into the binary with
# `include_dir!`; here they are read from data/word_lists at the same relative
# path and cached per language code.
#
# Upstream's `Language` enum carries a `strum` code (the file name of the word
# list, and the value stored in the `text-language` setting) and a message (the
# language's own name, as shown in the UI). Both live on Language instances
# here, in the same order the enum declares them.
#
module TextGeneration
  WORD_LIST_DIR = File.expand_path("../data/word_lists", __dir__)
  CHUNK_GRAPHEME_COUNT = 400

  # One kind of punctuation that can be inserted around a generated word.
  #
  # `prefix` and `suffix` are what gets put before and after the word (either
  # may be nil); `ends_sentence` says whether the next word should start with a
  # capitalized letter; `weight` says how much this kind should be used
  # compared to the others in its set.
  Punctuation = Struct.new(
    :prefix,
    :suffix,
    :ends_sentence,
    :weight,
  )

  # Builds a punctuation set out of rows of
  # [prefix, suffix, ends_sentence, weight]. Upstream writes each one as a
  # `Punctuation::suffix` or `Punctuation::wrapping` call; the house style caps
  # a call at three arguments, so the sets are data here and the two
  # convenience constructors are not needed.
  def self.punctuation_set(rows)
    rows.map do |prefix, suffix, ends_sentence, weight|
      Punctuation.new(
        prefix,
        suffix,
        ends_sentence,
        weight,
      )
    end.freeze
  end

  # A language the app can generate text for. All of them MUST have a
  # corresponding file in data/word_lists/{code}.txt.
  class Language
    attr_reader :code, :name

    def initialize(code, name)
      @code = code
      @name = name
    end

    def ==(other) = other.is_a?(Language) && other.code == @code

    alias eql? ==

    def hash = @code.hash

    def to_s = @code

    ALL = [
      new("ar", "العربية"),
      new("bn", "বাংলা"),
      new("eu", "Euskara"),
      new("bg", "Български"),
      new("ca", "Català"),
      new("cpp", "C++"),
      new("cs", "Čeština"),
      new("da", "Dansk"),
      new("nl", "Nederlands"),
      new("en", "English"),
      new("et", "Eesti"),
      new("fi", "Suomi"),
      new("fr", "Français"),
      new("de", "Deutsch"),
      new("el", "Ελληνικά"),
      new("he", "עברית"),
      new("hi", "हिन्दी"),
      new("hu", "Magyar"),
      new("id", "Bahasa Indonesia"),
      new("it", "Italiano"),
      new("js", "JavaScript"),
      new("kab", "Taqbaylit"),
      new("rw", "Kinyarwanda"),
      new("ko", "한국어"),
      new("ne", "नेपाली"),
      new("nb", "Norsk bokmål"),
      new("nn", "Norsk nynorsk"),
      new("oc", "Occitan"),
      new("pl", "Polski"),
      new("pt", "Português"),
      new("py", "Python"),
      new("ro", "Română"),
      new("ru", "Русский"),
      new("rs", "Rust"),
      new("sk", "Slovenčina"),
      new("es", "Español"),
      new("sw", "Swahili"),
      new("sv", "Svenska"),
      new("de_CH", "Schweizerdeutsch"),
      new("tr", "Türkçe"),
      new("uk", "Українська"),
      new("vn", "Tiếng Việt"),
      new("fa", "فارسی"),
    ].freeze

    DEFAULT = ALL.find { |language| language.code == "en" }

    # Upstream's `Language::from_str(...).unwrap_or(Language::English)`.
    def self.from_code(code) = ALL.find { |language| language.code == code } || DEFAULT
  end

  # A set of punctuation that works fine for most western languages
  GENERIC_PUNCTUATION = punctuation_set(
    [
      [nil, ".", true, 0.6],
      [nil, ",", false, 1.0],
      [nil, ";", false, 0.1],
      [nil, ":", false, 0.2],
      [nil, "!", true, 0.3],
      [nil, "?", true, 0.3],
      ["\"", "\"", false, 0.2],
      ["(", ")", false, 0.1],
    ],
  )

  PROGRAMMING_PUNCTUATION_C_LIKE = punctuation_set(
    [
      [nil, ";", false, 1.0],
      [nil, ",", false, 0.6],
      [nil, ":", false, 0.2],
      ["{ ", " }", false, 0.6],
      ["(", ")", false, 0.4],
      ["[", "]", false, 0.2],
      ["\"", "\"", false, 0.3],
      ["'", "'", false, 0.2],
    ],
  )

  PROGRAMMING_PUNCTUATION_PYTHON = punctuation_set(
    [
      [nil, ",", false, 1.0],
      [nil, ":", false, 0.8],
      ["(", ")", false, 0.4],
      ["[", "]", false, 0.2],
      ["{", "}", false, 0.2],
      ["\"", "\"", false, 0.3],
      ["'", "'", false, 0.2],
    ],
  )

  # Arabic has its own set of punctuation
  ARABIC_PUNCTUATION = punctuation_set(
    [
      [nil, ".", true, 0.6],
      [nil, "،", false, 1.0],
      [nil, "؛", false, 0.1],
      [nil, ":", false, 0.2],
      [nil, "!", true, 0.3],
      [nil, "؟", true, 0.3],
      ["\"", "\"", false, 0.2],
      ["(", ")", false, 0.1],
    ],
  )

  # Persian is similar to Arabic, but the quotation marks are not used and the
  # numerals are Persian ones.
  PERSIAN_PUNCTUATION = punctuation_set(
    [
      [nil, ".", true, 0.6],
      [nil, "،", false, 1.0],
      [nil, "؛", false, 0.1],
      [nil, ":", false, 0.2],
      [nil, "!", true, 0.3],
      [nil, "؟", true, 0.3],
      ["\"", "\"", false, 0.0],
      ["(", ")", false, 0.1],
    ],
  )

  # Bulgarians and Romanians have a pretty strong culture of using „ and “ over
  # " and ". See <https://github.com/bragefuglseth/keypunch/issues/41> and
  # <https://github.com/bragefuglseth/keypunch/pull/80>.
  LOW_HIGH_QUOTE_PUNCTUATION = punctuation_set(
    [
      [nil, ".", true, 0.6],
      [nil, ",", false, 1.0],
      [nil, ";", false, 0.1],
      [nil, ":", false, 0.2],
      [nil, "!", true, 0.3],
      [nil, "?", true, 0.3],
      ["„", "“", false, 0.2],
      ["(", ")", false, 0.1],
    ],
  )

  # See <https://github.com/bragefuglseth/keypunch/issues/58>. The quotation is
  # slightly different from the one above.
  CZECH_PUNCTUATION = punctuation_set(
    [
      [nil, ".", true, 0.6],
      [nil, ",", false, 1.0],
      [nil, ";", false, 0.1],
      [nil, ":", false, 0.2],
      [nil, "!", true, 0.3],
      [nil, "?", true, 0.3],
      ["„", "”", false, 0.2],
      ["(", ")", false, 0.1],
    ],
  )

  # The French language has a space before certain punctuation marks, and
  # keyboard layouts that allow for typing guillemet quotation marks easily.
  # See <https://github.com/bragefuglseth/keypunch/issues/47>
  FRENCH_PUNCTUATION = punctuation_set(
    [
      [nil, ".", true, 0.6],
      [nil, ",", false, 1.0],
      [nil, "\u202F;", false, 0.1],
      [nil, "\u202F:", false, 0.2],
      [nil, "\u202F!", true, 0.3],
      [nil, "\u202F?", true, 0.3],
      ["«\u202F", "\u202F»", false, 0.2],
      ["(", ")", false, 0.1],
    ],
  )

  GREEK_PUNCTUATION = punctuation_set(
    [
      [nil, ".", true, 0.6],
      [nil, ",", false, 1.0],
      [nil, "·", false, 0.1],
      [nil, ":", false, 0.2],
      [nil, "!", true, 0.3],
      [nil, ";", true, 0.3],
      ["\"", "\"", false, 0.2],
      ["(", ")", false, 0.1],
    ],
  )

  # Hindi, Nepali and Bangla use Devanagari punctuation
  DEVANAGARI_PUNCTUATION = punctuation_set(
    [
      [nil, "।", true, 0.6],
      [nil, ",", false, 1.0],
      [nil, ";", false, 0.1],
      [nil, ":", false, 0.2],
      [nil, "!", true, 0.3],
      [nil, "?", true, 0.3],
      ["\"", "\"", false, 0.2],
      ["(", ")", false, 0.1],
    ],
  )

  # Spanish has "wrapping" exclamation points and question marks
  SPANISH_PUNCTUATION = punctuation_set(
    [
      [nil, ".", true, 0.6],
      [nil, ",", false, 1.0],
      [nil, ";", false, 0.1],
      [nil, ":", false, 0.2],
      ["¡", "!", true, 0.3],
      ["¿", "?", true, 0.3],
      ["\"", "\"", false, 0.2],
      ["(", ")", false, 0.1],
    ],
  )

  # Portuguese has many words with accents and "ç", so advanced mode uses a
  # different, larger word list. The extra words are taken from
  # <https://github.com/monkeytypegame/monkeytype>.
  PORTUGUESE_PUNCTUATION = punctuation_set(
    [
      [nil, ".", true, 0.6],
      [nil, ",", false, 1.0],
      [nil, ";", false, 0.08],
      [nil, ":", false, 0.2],
      [nil, "!", true, 0.3],
      [nil, "?", true, 0.3],
      ["\"", "\"", false, 0.2],
      ["(", ")", false, 0.1],
    ],
  )

  WESTERN_ARABIC_NUMERALS = %w[0 1 2 3 4 5 6 7 8 9].freeze
  PERSIAN_NUMERALS = %w[۰ ۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹].freeze
  DEVANAGARI_NUMERALS = %w[० १ २ ३ ४ ५ ६ ७ ८ ९].freeze
  BANGLA_NUMERALS = %w[০ ১ ২ ৩ ৪ ৫ ৬ ৭ ৮ ৯].freeze

  # The languages whose advanced mode is generated without capitalization,
  # with their punctuation sets.
  PROGRAMMING_PUNCTUATIONS = {
    "cpp" => PROGRAMMING_PUNCTUATION_C_LIKE,
    "js"  => PROGRAMMING_PUNCTUATION_C_LIKE,
    "rs"  => PROGRAMMING_PUNCTUATION_C_LIKE,
    "py"  => PROGRAMMING_PUNCTUATION_PYTHON,
  }.freeze

  # The languages whose advanced mode reads from a word list of its own.
  ADVANCED_WORD_LISTS = {
    "ar" => "ar_advanced",
    "fa" => "fa_advanced",
    "pt" => "pt_advanced",
  }.freeze

  # The punctuation set each language's advanced mode uses, where it is not the
  # generic one.
  ADVANCED_PUNCTUATIONS = {
    "ar" => ARABIC_PUNCTUATION,
    "fa" => PERSIAN_PUNCTUATION,
    "bg" => LOW_HIGH_QUOTE_PUNCTUATION,
    "ro" => LOW_HIGH_QUOTE_PUNCTUATION,
    "cs" => CZECH_PUNCTUATION,
    "fr" => FRENCH_PUNCTUATION,
    "el" => GREEK_PUNCTUATION,
    "bn" => DEVANAGARI_PUNCTUATION,
    "hi" => DEVANAGARI_PUNCTUATION,
    "ne" => DEVANAGARI_PUNCTUATION,
    "es" => SPANISH_PUNCTUATION,
    "pt" => PORTUGUESE_PUNCTUATION,
  }.freeze

  # The numeral set each language's advanced mode uses, where it is not the
  # western Arabic one.
  ADVANCED_NUMERALS = {
    "fa" => PERSIAN_NUMERALS,
    "bn" => BANGLA_NUMERALS,
    "hi" => DEVANAGARI_NUMERALS,
    "ne" => DEVANAGARI_NUMERALS,
  }.freeze

  # The tuples consist of a number length and the proportion of numbers that
  # should have that amount of digits.
  NUMBER_LENGTH_WEIGHTS = [[1, 0.4], [2, 0.3], [3, 0.2], [4, 0.1]].freeze

  module_function

  # Only lowercase letters, no punctuation or numbers
  def simple(language) = simple_generic(language.code, " ")

  # Some capitalized letters, punctuation and numbers
  def advanced(language)
    programming = PROGRAMMING_PUNCTUATIONS[language.code]

    if programming
      advanced_programming(
        language.code,
        " ",
        programming,
        WESTERN_ARABIC_NUMERALS,
      )
    else
      advanced_generic(
        ADVANCED_WORD_LISTS.fetch(language.code, language.code),
        " ",
        ADVANCED_PUNCTUATIONS.fetch(language.code, GENERIC_PUNCTUATION),
        ADVANCED_NUMERALS.fetch(language.code, WESTERN_ARABIC_NUMERALS),
      )
    end
  end

  # Should work for most languages
  def simple_generic(lang_code, spacing)
    random_words_from_lang_code(lang_code).map { |word| word + spacing }.join
  end

  # Should work for most languages
  def advanced_generic(lang_code, spacing, punctuations, numerals)
    generated = random_words_from_lang_code(lang_code)

    # The very first letter in the chunk should always be capitalized
    generated[0] = uppercase_first_letter(generated[0])

    insert_numbers(generated, numerals)

    # Sample from the entire text except for the last word, since that gets
    # punctuation further down in the function
    sample_indices(generated.length - 2, generated.length / 4).each do |index|
      punctuation = choose_weighted(punctuations)
      generated[index] = insert_punctuation(generated[index], punctuation)

      if punctuation.ends_sentence && generated[index + 1]
        generated[index + 1] = uppercase_first_letter(generated[index + 1])
      end
    end

    # Insert random "sentence ending" punctuation on last word
    end_punctuation = punctuations.select(&:ends_sentence).sample
    generated[-1] = insert_punctuation(generated[-1], end_punctuation)

    generated.map { |word| word + spacing }.join
  end

  # Similar to advanced_generic, but does not capitalize any letters
  def advanced_programming(lang_code, spacing, punctuations, numerals)
    generated = random_words_from_lang_code(lang_code)

    insert_numbers(generated, numerals)

    sample_indices(generated.length, generated.length / 4).each do |index|
      generated[index] = insert_punctuation(generated[index], choose_weighted(punctuations))
    end

    generated.map { |word| word + spacing }.join
  end

  # Swaps out some words with numbers
  def insert_numbers(generated, numerals)
    sample_indices(generated.length, generated.length / 20).each do |index|
      generated[index] = random_number_weighted(numerals)
    end
  end

  def uppercase_first_letter(string)
    found = false

    string.each_char.map do |char|
      if char.match?(/[[:alnum:]]/) && !found
        found = true
        char.upcase
      else
        char
      end
    end.join
  end

  def words_from_lang_code(lang_code)
    @word_lists ||= {}
    @word_lists[lang_code] ||= File
      .read(File.join(WORD_LIST_DIR, "#{lang_code}.txt"))
      .lines
      .map(&:chomp)
      .reject(&:empty?)
      .freeze
  end

  # Picks words at random until the chunk is long enough, never repeating any
  # of the two words before it.
  def random_words_from_lang_code(lang_code)
    word_list = words_from_lang_code(lang_code)

    [].tap do |generated|
      count = 0

      while count < CHUNK_GRAPHEME_COUNT
        new_word = word_list.sample

        if generated.last(2).none?(new_word)
          generated << new_word
          count += TextUtils.graphemes(new_word).length
        end
      end
    end
  end

  def insert_punctuation(word, punctuation)
    "#{punctuation.prefix}#{word}#{punctuation.suffix}"
  end

  # Generates a number between 0 and 9999, with support for multiple numeral
  # systems and a bias towards smaller numbers.
  def random_number_weighted(numerals)
    length = choose_weighted_pairs(NUMBER_LENGTH_WEIGHTS)

    Array.new(length) { numerals.sample }.join
  end

  # `amount` distinct indices below `population`, upstream's
  # `rand::seq::index::sample`.
  def sample_indices(population, amount)
    if population < 1 || amount < 1
      []
    else
      (0...population).to_a.sample([amount, population].min)
    end
  end

  # Upstream's `choose_weighted` over a slice of punctuation.
  def choose_weighted(punctuations)
    choose_weighted_pairs(punctuations.map { |punctuation| [punctuation, punctuation.weight] })
  end

  # Picks the first element of a [value, weight] pair, with a probability
  # proportional to its weight.
  def choose_weighted_pairs(pairs)
    total = pairs.sum { |_value, weight| weight }
    target = rand * total
    running = 0.0
    chosen = nil

    pairs.each do |value, weight|
      running += weight

      if chosen.nil? && running > target
        chosen = value
      end
    end

    chosen || pairs.last.first
  end
end
