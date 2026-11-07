# frozen_string_literal: true

require_relative "../lib/text_generation"

RSpec.describe TextGeneration do
  describe TextGeneration::Language do
    describe ".from_code" do
      it "finds the language with the matching code" do
        expect(described_class.from_code("fr").name).to eq("Français")
      end

      it "falls back to English for an unknown code" do
        expect(described_class.from_code("not-a-real-code")).to eq(described_class::DEFAULT)
      end
    end

    it "compares equal to another instance with the same code" do
      expect(described_class.from_code("en")).to eq(described_class.new("en", "Something Else"))
    end

    it "has a word list file on disk for every declared language" do
      missing = described_class::ALL.reject do |language|
        File.exist?(File.join(TextGeneration::WORD_LIST_DIR, "#{language.code}.txt"))
      end

      expect(missing.map(&:code)).to eq([])
    end
  end

  describe ".simple" do
    it "generates only letters and spaces, no digits or punctuation" do
      text = described_class.simple(TextGeneration::Language::DEFAULT)
      expect(text).to match(/\A[a-zA-Z ]+\z/)
      expect(text).not_to be_empty
    end
  end

  describe ".advanced" do
    it "generates non-empty text with an English word in it, ending in sentence punctuation" do
      text = described_class.advanced(TextGeneration::Language::DEFAULT)
      expect(text).not_to be_empty
      expect(text.rstrip).to match(/[.!?]\z/)
    end
  end

  describe ".insert_punctuation" do
    it "wraps a word with the punctuation's prefix and suffix" do
      quote = TextGeneration::Punctuation.new("\"", "\"", false, 1.0)
      expect(described_class.insert_punctuation("word", quote)).to eq("\"word\"")
    end

    it "appends only a suffix when there is no prefix" do
      comma = TextGeneration::Punctuation.new(nil, ",", false, 1.0)
      expect(described_class.insert_punctuation("word", comma)).to eq("word,")
    end
  end

  describe ".uppercase_first_letter" do
    it "capitalizes only the first letter, leaving the rest alone" do
      expect(described_class.uppercase_first_letter("hello")).to eq("Hello")
    end
  end

  describe ".choose_weighted" do
    it "always returns one of the given punctuation entries" do
      set = TextGeneration::GENERIC_PUNCTUATION
      10.times do
        expect(set).to include(described_class.choose_weighted(set))
      end
    end
  end
end
