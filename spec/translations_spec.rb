# frozen_string_literal: true

require_relative "../lib/translations"

RSpec.describe Translations do
  describe ".fmt" do
    it "fills the {} placeholders left to right" do
      expect(described_class.fmt("{} of {}", 3, 10)).to eq("3 of 10")
    end

    it "leaves the string alone when it has no placeholder" do
      expect(described_class.fmt("no blocks here", 1)).to eq("no blocks here")
    end
  end

  describe Translations::Plural do
    describe ".parse / #index_for" do
      it "defaults to English's two-form rule when the header is empty" do
        plural = described_class.parse("")
        expect(plural.index_for(1)).to eq(0)
        expect(plural.index_for(0)).to eq(1)
        expect(plural.index_for(5)).to eq(1)
      end

      it "evaluates Polish's three-way plural rule" do
        header = "nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);"
        plural = described_class.parse(header)

        expect(plural.index_for(1)).to eq(0)
        expect(plural.index_for(2)).to eq(1)
        expect(plural.index_for(5)).to eq(2)
        expect(plural.index_for(12)).to eq(2)
        expect(plural.index_for(22)).to eq(1)
      end

      it "evaluates Arabic's six-way plural rule" do
        header = "nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5);"
        plural = described_class.parse(header)

        expect(plural.index_for(0)).to eq(0)
        expect(plural.index_for(1)).to eq(1)
        expect(plural.index_for(2)).to eq(2)
        expect(plural.index_for(5)).to eq(3)
        expect(plural.index_for(15)).to eq(4)
        expect(plural.index_for(100)).to eq(5)
      end

      it "clamps an index a lying header would push out of range" do
        plural = described_class.parse("nplurals=1; plural=5;")
        expect(plural.index_for(42)).to eq(0)
      end
    end
  end

  describe Translations::Catalogue do
    describe ".parse" do
      it "reads a msgid/msgstr pair into the message table" do
        source = <<~PO
          msgid "Hello"
          msgstr "Bonjour"
        PO

        messages = described_class.parse(source)
        expect(messages["Hello"]).to eq(["Bonjour"])
      end

      it "keys a message with a msgctxt separately from one without" do
        glue = Translations::CONTEXT_GLUE
        source = <<~PO
          msgctxt "greeting"
          msgid "Hi"
          msgstr "Salut"

          msgid "Hi"
          msgstr "Coucou"
        PO

        messages = described_class.parse(source)
        expect(messages["greeting#{glue}Hi"]).to eq(["Salut"])
        expect(messages["Hi"]).to eq(["Coucou"])
      end

      it "unescapes a quoted newline and tab" do
        source = <<~'PO'
          msgid "a\nb\tc"
          msgstr "x\ny\tz"
        PO

        messages = described_class.parse(source)
        expect(messages["a\nb\tc"]).to eq(["x\ny\tz"])
      end

      it "drops a fuzzy entry, treating it as untranslated" do
        source = <<~PO
          #, fuzzy
          msgid "Stale"
          msgstr "Perime"
        PO

        messages = described_class.parse(source)
        expect(messages).not_to have_key("Stale")
      end
    end

    describe "#singular" do
      it "falls back to the msgid when the catalogue has no translation for it" do
        catalogue = described_class.new(nil, "")
        expect(catalogue.singular(nil, "Untranslated")).to eq("Untranslated")
      end

      it "returns the stored translation when there is one" do
        source = <<~PO
          msgid "Hello"
          msgstr "Bonjour"
        PO
        catalogue = described_class.new("fr", source)
        expect(catalogue.singular(nil, "Hello")).to eq("Bonjour")
      end

      it "falls back to the msgid when the stored translation is empty" do
        source = <<~PO
          msgid "Hello"
          msgstr ""
        PO
        catalogue = described_class.new("fr", source)
        expect(catalogue.singular(nil, "Hello")).to eq("Hello")
      end
    end

    describe "#plural" do
      it "falls back to English's own plural rule with no catalogue entry" do
        catalogue = described_class.new(nil, "")
        expect(catalogue.plural(nil, "%d word", "%d words", 1)).to eq("%d word")
        expect(catalogue.plural(nil, "%d word", "%d words", 2)).to eq("%d words")
      end

      it "picks the stored plural form the count's index selects" do
        source = <<~'PO'
          msgid ""
          msgstr "Plural-Forms: nplurals=2; plural=(n != 1);\n"

          msgid "%d word"
          msgid_plural "%d words"
          msgstr[0] "%d mot"
          msgstr[1] "%d mots"
        PO
        catalogue = described_class.new("fr", source)
        expect(catalogue.plural(nil, "%d word", "%d words", 1)).to eq("%d mot")
        expect(catalogue.plural(nil, "%d word", "%d words", 3)).to eq("%d mots")
      end
    end
  end
end
