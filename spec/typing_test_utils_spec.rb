# frozen_string_literal: true

require_relative "../lib/typing_test_utils"

RSpec.describe TypingTestUtils do
  describe TypingTestUtils::GeneratedTestDifficulty do
    it "round-trips the settings nicks it was given" do
      expect(described_class.from_settings_string("Advanced")).to eq(described_class::ADVANCED)
    end

    it "returns nil for an unknown nick" do
      expect(described_class.from_settings_string("Nonsense")).to be_nil
    end
  end

  describe TypingTestUtils::TestDuration do
    it "maps every nick to the seconds the countdown timer uses" do
      expect(described_class.seconds(described_class::MIN1)).to eq(60)
      expect(described_class.seconds(described_class::MIN10)).to eq(600)
    end

    it "falls back to the default duration's seconds for an unknown nick" do
      expect(described_class.seconds("bogus")).to eq(described_class.seconds(described_class::DEFAULT))
    end
  end

  describe TypingTestUtils::PresenceState do
    it "has an English string for every state" do
      expect(described_class.english_string(described_class::READY)).to eq("Ready to start")
      expect(described_class.english_string(described_class::TYPING)).to eq("Typing")
      expect(described_class.english_string(described_class::RESULTS)).to eq("Viewing results")
    end
  end

  describe TypingTestUtils::TestConfig do
    it "builds a finite config for a Custom session" do
      config = described_class.finite
      expect(config.finite?).to be(true)
      expect(config.generated?).to be(false)
    end

    it "builds a generated config with language/difficulty/duration" do
      config = described_class.generated(
        language:   TextGeneration::Language::DEFAULT,
        difficulty: TypingTestUtils::GeneratedTestDifficulty::SIMPLE,
        duration:   TypingTestUtils::TestDuration::SEC30,
      )
      expect(config.generated?).to be(true)
      expect(config.language).to eq(TextGeneration::Language::DEFAULT)
    end

    it "compares equal by value, not identity" do
      a = described_class.finite
      b = described_class.finite
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end
  end

  describe TypingTestUtils::TestSummary do
    describe ".accuracy_of" do
      it "is 0.0 for a test with no keystrokes at all" do
        expect(described_class.accuracy_of([])).to eq(0.0)
      end

      it "is the fraction of correct keystrokes" do
        keystrokes = [[0.0, true], [0.1, true], [0.2, false], [0.3, true]]
        expect(described_class.accuracy_of(keystrokes)).to eq(0.75)
      end

      it "is 0.0 when every keystroke was wrong" do
        keystrokes = [[0.0, false], [0.1, false]]
        expect(described_class.accuracy_of(keystrokes)).to eq(0.0)
      end
    end
  end
end
