# frozen_string_literal: true

# Translations is the app's gettext catalogue: the message lookups every
# user-visible string goes through, and the PO reader behind them.
#
# Ported from upstream's po/ directory together with the gettext setup at the
# top of src/main.rs, which calls `bindtextdomain`, `bind_textdomain_codeset`
# and `textdomain` so the `gettext`, `ngettext` and `pgettext` calls spread
# through the Rust sources find the catalogue meson compiled and installed.
#
# That install step is where this port diverges. The app runs from a checkout,
# so there is no $LOCALEDIR of compiled .mo files to bind; the .po files
# shipped in po/ are the catalogue instead, and `Catalogue` reads the one
# matching the current locale directly, header included. `Plural` turns that
# header's `Plural-Forms` expression into the index chooser `ngettext` needs,
# so the 37 locales keep their own plural rules rather than English's.
#
# A message with no translation, a message whose translation is empty and a
# locale with no .po file at all all fall back to the msgid, which is what
# gettext itself does.
#
# The `_`, `N_`, `n_` and `p_` helpers carry the names ruby-gettext's
# rxgettext extracts by default, which is what upstream's po/meson.build
# stands in for here. po/POTFILES.in lists the sources that hold msgids, and
# the template and the catalogues are brought back up to date with them by:
#
#   rxgettext -o keypunch.pot --package-name=keypunch --package-version="" \
#     --add-comments=Translators --sort-by-file $(cat po/POTFILES.in)
#   msgcat --width=79 -o po/keypunch.pot keypunch.pot && rm keypunch.pot
#   for l in $(cat po/LINGUAS); do \
#     msgmerge --quiet --width=79 --backup=none --update po/$l.po po/keypunch.pot; \
#   done
#
# rxgettext writes the template beside the sources and relativises its `#:`
# references to wherever it lands, which is why it writes to the root and
# msgcat moves it in — msgcat also rewraps the long msgids, which rxgettext
# breaks mid-word.
#
# Two things rxgettext cannot see: a msgid built from a constant rather than a
# literal, and a `p_` whose context is a constant. So a msgid that has to live
# in a constant is marked with `N_` there and translated with `_` at the call,
# and a context is always written out in full at the lookup.
#
module Translations
  DOMAIN = "keypunch"

  PO_DIR = File.expand_path("../po", __dir__)

  # How gettext keys a message that carries a msgctxt: context, an EOT byte,
  # then the msgid.
  CONTEXT_GLUE = "\u0004"

  # The placeholder upstream's translatable format strings use, and which
  # `fmt` fills in left to right. Upstream gets the same behaviour from the
  # `i18n_fmt!` macro of the i18n-format crate.
  PLACEHOLDER = "{}"

  # The call-site helpers. One `include Translations::Helpers` makes them
  # available both to a class's instances and to its own body, so the same
  # mixin serves the methods that build widgets and the constants that hold
  # the msgids those methods translate.
  module Helpers
    def self.included(base) = base.extend(self)

    # gettext: the translation of `msgid`, or `msgid` itself.
    def _(msgid) = Translations.gettext(msgid)

    # The no-op marker. It leaves the string alone and exists so a msgid
    # written somewhere the translation cannot be done yet — a frozen
    # constant, evaluated before the locale is known — still reaches the pot.
    # The call site translates it later with `_`.
    def N_(msgid) = msgid

    # ngettext: the plural form of the translation that `count` selects.
    def n_(singular, plural, count) = Translations.ngettext(singular, plural, count)

    # pgettext: the translation of `msgid` as disambiguated by `context`.
    def p_(context, msgid) = Translations.pgettext(context, msgid)

    # Fills the `{}` blocks of a translated format string, left to right.
    def fmt(format, *values) = Translations.fmt(format, *values)
  end

  module_function

  # Upstream's bindtextdomain/textdomain pair: it names the directory the
  # catalogue is read from and the locale to read out of it. Both are
  # optional, and every lookup below binds the environment's locale on first
  # use, so this only has to be called to override one of them.
  def bind(dir: PO_DIR, locale: nil)
    @catalogue = Catalogue.load(dir, locale || Locale.preferred(dir))
  end

  def catalogue = @catalogue ||= bind

  def gettext(msgid) = catalogue.singular(nil, msgid)

  def ngettext(singular, plural, count) = catalogue.plural(
    nil,
    singular,
    plural,
    count,
  )

  def pgettext(context, msgid) = catalogue.singular(context, msgid)

  # Fills a translated format string: each `{}` block is replaced by the next
  # value, left to right. Translators are free to reorder the surrounding
  # text but not the blocks, exactly as upstream's `i18n_fmt!` has it.
  def fmt(format, *values)
    values.inject(format) { |text, value| text.sub(PLACEHOLDER, value.to_s) }
  end

  # Which locale to read, in gettext's own order of preference: LANGUAGE
  # first, as a colon-separated list of names to try in turn, then LC_ALL,
  # LC_MESSAGES and LANG. A name is tried both in full and stripped of its
  # territory, so `pt_BR` falls back to `pt`, and the C locale asks for no
  # catalogue at all.
  module Locale
    VARIABLES = %w[LANGUAGE LC_ALL LC_MESSAGES LANG].freeze

    UNTRANSLATED = %w[C POSIX].freeze

    module_function

    def preferred(dir, environment: ENV)
      candidates(environment).find { |name| File.file?(File.join(dir, "#{name}.po")) }
    end

    def candidates(environment)
      VARIABLES.flat_map { |variable| environment[variable].to_s.split(":") }
        .flat_map { |name| expand(name) }
        .reject { |name| name.empty? || UNTRANSLATED.include?(name) }
        .uniq
    end

    # `nb_NO.UTF-8@valencia` names the locale `nb_NO`, which falls back to
    # `nb`. The encoding and the modifier never name a catalogue file.
    def expand(name)
      name.split(".").first.to_s.split("@").first.to_s.then do |bare|
        [bare, bare.split("_").first.to_s].uniq
      end
    end
  end

  # One locale's messages, read from its .po file.
  #
  # The PO format is the catalogue here, so the parsing is done in full: the
  # multi-line string continuations, the escapes, the `msgctxt` keys, the
  # indexed `msgstr[n]` plural forms, and the two kinds of entry gettext
  # ignores — the ones flagged fuzzy, which are a translator's work in
  # progress, and the obsolete `#~` ones left behind by msgmerge.
  class Catalogue
    OBSOLETE_PATTERN = /\A#~/
    FLAGS_PATTERN = /\A#,/
    COMMENT_PATTERN = /\A#/

    ESCAPES = {
      "\\n"  => "\n",
      "\\t"  => "\t",
      "\\r"  => "\r",
      "\\\"" => "\"",
      "\\\\" => "\\",
    }.freeze

    ESCAPE_PATTERN = /\\[ntr"\\]/

    KEYWORD_PATTERN = /\A(msgctxt|msgid_plural|msgid|msgstr(?:\[(\d+)\])?)\s+(".*")\s*\z/
    CONTINUATION_PATTERN = /\A".*"\s*\z/
    STRING_PATTERN = /"((?:[^"\\]|\\.)*)"/

    HEADER_PATTERN = /\A([\w-]+)\s*:\s*(.*)\z/

    attr_reader :locale, :plural_forms

    def self.load(dir, locale)
      if locale
        new(locale, File.read(File.join(dir, "#{locale}.po"), encoding: "UTF-8"))
      else
        new(nil, "")
      end
    end

    def initialize(locale, source)
      @locale = locale
      @messages = self.class.parse(source)
      @plural_forms = Plural.parse(headers["Plural-Forms"])
    end

    # The header entry, the one whose msgid is empty, holds the catalogue's
    # metadata as mail-style fields.
    def headers
      @headers ||= @messages.fetch("", [""]).first.to_s.lines.filter_map do |line|
        HEADER_PATTERN.match(line.chomp).then do |match|
          if match
            [match[1], match[2]]
          end
        end
      end.to_h
    end

    def singular(context, msgid)
      form(key(context, msgid), 0) || msgid
    end

    def plural(context, one, many, count)
      form(key(context, one), plural_forms.index_for(count)) ||
        self.class.english_form(one, many, count)
    end

    # The fallback when the catalogue has nothing: the msgids themselves, with
    # the source language's own two-form rule.
    def self.english_form(one, many, count)
      if count == 1
        one
      else
        many
      end
    end

    def self.parse(source)
      source.each_line.inject(Parser.new) { |parser, line| parser.read(line) }.messages
    end

    def self.unescape(line)
      line.scan(STRING_PATTERN).flatten.join.gsub(ESCAPE_PATTERN) { |escape| ESCAPES.fetch(escape) }
    end

    # The state machine behind `Catalogue.parse`: one entry is built up across
    # the lines that describe it, then flushed into `messages` when the next
    # entry starts or the file ends.
    class Parser
      def initialize
        @messages = {}
        @entry = {}
        @field = nil
        @fuzzy = false
      end

      def read(line)
        tap do
          line.strip.then do |stripped|
            if stripped.empty?
              flush
            else
              read_content(stripped)
            end
          end
        end
      end

      def messages
        flush
        @messages
      end

      private

        def read_content(line)
          case line
          when OBSOLETE_PATTERN then skip
          when FLAGS_PATTERN then read_flags(line)
          when COMMENT_PATTERN then @field = nil
          when KEYWORD_PATTERN then read_keyword(Regexp.last_match)
          when CONTINUATION_PATTERN then append(line)
          end
        end

        # An obsolete entry ends whatever entry preceded it and contributes
        # nothing of its own.
        def skip
          flush
          @field = nil
        end

        def read_flags(line)
          @fuzzy ||= line.split(",").map(&:strip).include?("fuzzy")
        end

        def read_keyword(match)
          match[1].then do |keyword|
            start_entry(keyword)
            @field = field_for(keyword, match[2])
            @entry[@field] = Catalogue.unescape(match[3])
          end
        end

        # A `msgctxt` or `msgid` line belongs to the next entry, not the one
        # being read, so it is where entries are cut apart.
        def start_entry(keyword)
          if %w[msgctxt msgid].include?(keyword) && @entry.key?("msgid")
            flush
          end
        end

        def field_for(keyword, index)
          if index
            "msgstr[#{index.to_i}]"
          else
            keyword
          end
        end

        def append(line)
          if @field
            @entry[@field] = @entry[@field].to_s + Catalogue.unescape(line)
          end
        end

        def flush
          if @entry.key?("msgid")
            store
          end

          @entry = {}
          @field = nil
          @fuzzy = false
        end

        # A fuzzy entry is a translation the translator has not confirmed;
        # gettext treats it as absent, and so does this. The header entry is
        # the exception: msginit leaves it flagged fuzzy in catalogues that
        # are otherwise finished, and gettext reads it anyway.
        def store
          if !@fuzzy || @entry["msgid"].to_s.empty?
            @messages[entry_key] = forms
          end
        end

        def entry_key
          @entry["msgctxt"].then do |context|
            if context
              "#{context}#{CONTEXT_GLUE}#{@entry['msgid']}"
            else
              @entry["msgid"]
            end
          end
        end

        # Either a lone `msgstr` or the indexed plural forms, in index order.
        def forms
          @entry.keys.grep(/\Amsgstr\[\d+\]\z/)
            .sort_by { |field| field[/\d+/].to_i }
            .map { |field| @entry[field] }
            .then do |indexed|
              if indexed.empty?
                [@entry["msgstr"].to_s]
              else
                indexed
              end
            end
        end
    end

    private

      def key(context, msgid)
        if context
          "#{context}#{CONTEXT_GLUE}#{msgid}"
        else
          msgid
        end
      end

      def form(key, index)
        @messages.fetch(key, nil).to_a[index].then do |translation|
          if translation.to_s.empty?
            nil
          else
            translation
          end
        end
      end

  end

  # A catalogue's `Plural-Forms` header: how many plural forms the language
  # has, and the C expression that picks one for a given count.
  #
  # The expression is the part that cannot be skipped. Of the 37 locales here,
  # Arabic has six forms chosen by a five-deep nested ternary and the Slavic
  # ones three chosen by modulo arithmetic, so the header is parsed and
  # evaluated rather than approximated.
  class Plural
    DEFAULT_COUNT = 2

    # The rule of English, and of every catalogue whose header is missing.
    DEFAULT_EXPRESSION = "n != 1"

    FIELD_PATTERN = /\A\s*([\w-]+)\s*=\s*(.*)\z/

    attr_reader :count

    def self.parse(header)
      fields(header).then do |fields|
        new(
          fields.fetch("nplurals", DEFAULT_COUNT.to_s).to_i,
          fields.fetch("plural", DEFAULT_EXPRESSION),
        )
      end
    end

    def self.fields(header)
      header.to_s.split(";").filter_map do |field|
        FIELD_PATTERN.match(field).then do |match|
          if match
            [match[1], match[2].strip]
          end
        end
      end.to_h
    end

    def initialize(count, expression)
      @count = [count, 1].max
      @expression = Expression.parse(expression)
    end

    # The index into a message's plural forms. A header that lies about its
    # own form count — or an expression that does — must not reach past the
    # forms the entry actually has, so the result is clamped.
    def index_for(number)
      @expression.call(number.to_i).clamp(0, @count - 1)
    end

    # The C expression of a `Plural-Forms` header, parsed once into a tree of
    # procs that each take the count and return an integer.
    #
    # Everything the headers use is here: the conditional operator, the
    # logical and comparison operators, and the arithmetic ones. C has no
    # booleans in this dialect, so a comparison yields 1 or 0 and a condition
    # is true when it is non-zero, which is exactly how the headers read.
    class Expression
      TOKEN_PATTERN = /\d+|n\b|\|\||&&|==|!=|<=|>=|[?:<>+\-*\/%!()]/

      FLAG = ->(value) { value ? 1 : 0 }

      OPERATIONS = {
        "||" => ->(left, right) { FLAG.call(left.nonzero? || right.nonzero?) },
        "&&" => ->(left, right) { FLAG.call(left.nonzero? && right.nonzero?) },
        "==" => ->(left, right) { FLAG.call(left == right) },
        "!=" => ->(left, right) { FLAG.call(left != right) },
        "<=" => ->(left, right) { FLAG.call(left <= right) },
        ">=" => ->(left, right) { FLAG.call(left >= right) },
        "<"  => ->(left, right) { FLAG.call(left < right) },
        ">"  => ->(left, right) { FLAG.call(left > right) },
        "+"  => ->(left, right) { left + right },
        "-"  => ->(left, right) { left - right },
        "*"  => ->(left, right) { left * right },
        "/"  => ->(left, right) { left / right },
        "%"  => ->(left, right) { left % right },
      }.freeze

      # Lowest to highest binding, the levels C gives these operators.
      LEVELS = [["||"], ["&&"], %w[== !=], %w[< > <= >=], %w[+ -], %w[* / %]].freeze

      COUNT = ->(number) { number }

      def self.parse(source)
        new(source).parse
      end

      def initialize(source)
        @tokens = source.to_s.scan(TOKEN_PATTERN)
        @position = 0
      end

      # A header this parser cannot read is worth less than English's rule,
      # not worth a crash in the middle of drawing a results page.
      def parse
        conditional
      rescue KeyError, NoMethodError, TypeError
        Expression.new(DEFAULT_EXPRESSION).conditional
      end

      # The conditional operator, right-associative: `a ? b : c ? d : e`
      # groups as `a ? b : (c ? d : e)`, which is how the Arabic and Slavic
      # headers are written.
      def conditional
        binary(0).then do |condition|
          if peek == "?"
            take
            branches(condition)
          else
            condition
          end
        end
      end

      private

        def branches(condition)
          conditional.then do |consequent|
            expect(":")
            conditional.then do |alternative|
              ->(number) do
                if condition.call(number).nonzero?
                  consequent.call(number)
                else
                  alternative.call(number)
                end
              end
            end
          end
        end

        def binary(level)
          operators = LEVELS[level]

          if operators
            node = binary(level + 1)

            while operators.include?(peek)
              node = combine(take, node, binary(level + 1))
            end

            node
          else
            unary
          end
        end

        def combine(operator, left, right)
          OPERATIONS.fetch(operator).then do |operation|
            ->(number) { operation.call(left.call(number), right.call(number)) }
          end
        end

        def unary
          case peek
          when "!" then negation
          when "-" then negative
          else primary
          end
        end

        def negation
          take
          unary.then { |node| ->(number) { FLAG.call(node.call(number).zero?) } }
        end

        def negative
          take
          unary.then { |node| ->(number) { -node.call(number) } }
        end

        def primary
          case peek
          when "(" then parenthesised
          when "n" then counted
          when /\A\d+\z/ then literal
          else unparsable
          end
        end

        def parenthesised
          take
          conditional.tap { expect(")") }
        end

        def counted
          take
          COUNT
        end

        def literal
          take.to_i.then { |value| ->(_number) { value } }
        end

        # Nothing a `Plural-Forms` header can hold reaches this, so a token
        # that does means the header is not one; `parse` falls back.
        def unparsable
          raise(TypeError, "unparsable plural expression at #{peek.inspect}")
        end

        def peek = @tokens[@position]

        def take
          @tokens[@position].tap { @position += 1 }
        end

        def expect(token)
          if peek == token
            take
          else
            unparsable
          end
        end
    end
  end
end
