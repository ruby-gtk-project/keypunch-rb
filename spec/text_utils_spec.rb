# frozen_string_literal: true

require_relative "../lib/text_utils"

RSpec.describe TextUtils do
  describe ".graphemes" do
    it "splits ASCII text into one grapheme per character" do
      expect(described_class.graphemes("abc")).to eq(%w[a b c])
    end

    it "keeps a combining-mark sequence as a single grapheme" do
      # "e" + COMBINING ACUTE ACCENT is one extended grapheme cluster.
      combined = "é"
      expect(described_class.graphemes(combined)).to eq([combined])
    end
  end

  describe ".lines_inclusive" do
    it "keeps the trailing newline on every line but the last" do
      expect(described_class.lines_inclusive("one\ntwo\nthree")).to eq(["one\n", "two\n", "three"])
    end
  end

  describe ".unicode_words" do
    it "keeps only the alphanumeric segments, dropping whitespace and punctuation" do
      expect(described_class.unicode_words("Hello, world! 123")).to eq(["Hello", "world", "123"])
    end
  end

  describe ".pop_graphemes" do
    it "removes the given number of trailing graphemes" do
      expect(described_class.pop_graphemes("hello", 2)).to eq("hel")
    end

    it "never goes below an empty string" do
      expect(described_class.pop_graphemes("hi", 10)).to eq("")
    end
  end

  describe ".alias_for / .replacement" do
    it "finds the French typing alias for Æ" do
      expect(described_class.alias_for("Æ")).to eq("Ae")
    end

    it "returns nil for a grapheme with no alias" do
      expect(described_class.alias_for("x")).to be_nil
    end

    it "finds the visual marker for a newline" do
      expect(described_class.replacement("\n")).to eq("↲\n")
    end
  end

  describe ".calculate_wpm" do
    it "counts a word as five correct characters per the elapsed minutes" do
      # 60 seconds, 10 correct characters => 2 words => 2.0 WPM.
      original = "a" * 10
      typed = "a" * 10
      expect(described_class.calculate_wpm(60.0, original, typed)).to eq(2.0)
    end

    it "only counts characters that match the original at the same position" do
      original = "abcdefghij"
      typed = "abcdeXXXXX" # first 5 correct, rest wrong
      # 5 correct chars / 5 = 1 word, over 1 minute = 1.0 WPM
      expect(described_class.calculate_wpm(60.0, original, typed)).to eq(1.0)
    end
  end

  describe ".validate_with_replacements" do
    it "marks every typed grapheme correct when it matches the original exactly" do
      result = described_class.validate_with_replacements("abc", "abc", 0)
      states = result.map(&:first)
      expect(states).to eq([TextUtils::CORRECT, TextUtils::CORRECT, TextUtils::CORRECT])
    end

    it "marks a wrong grapheme as a mistake" do
      result = described_class.validate_with_replacements("abc", "aXc", 0)
      states = result.map(&:first)
      expect(states[1]).to eq(TextUtils::MISTAKE)
    end
  end

  describe ".pop_word" do
    it "moves the caret back to the start of the current word" do
      expect(described_class.pop_word("hello world", "hello wor")).to eq("hello ")
    end
  end

  describe ".current_word" do
    it "is 1-based and counts the word the caret is inside" do
      expect(described_class.current_word("hello world", "hello wo".length)).to eq(2)
    end

    it "is 0 before any word has been reached" do
      expect(described_class.current_word("hello world", 0)).to eq(0)
    end
  end
end
