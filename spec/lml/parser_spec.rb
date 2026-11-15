# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ladl::Lml::Parser do
  subject(:document) { described_class.parse(source) }

  context "with a minimal instance" do
    let(:source) do
      <<~LML
        // a comment line
        instance Foo < Bar {
          name = "the value"
          count = 3
          flag = true
          nothing = null
          ref = OtherInstance
        }
      LML
    end

    it "parses one instance" do
      expect(document.instances.size).to eq(1)
    end

    it "captures the instance name and base class" do
      instance = document.instances.first
      expect(instance.name).to eq("Foo")
      expect(instance.base).to eq("Bar")
    end

    it "parses string values" do
      expect(document.instances.first.attributes["name"]).to eq("the value")
    end

    it "parses integer values" do
      expect(document.instances.first.attributes["count"]).to eq(3)
    end

    it "parses boolean and null values" do
      attrs = document.instances.first.attributes
      expect(attrs["flag"]).to be(true)
      expect(attrs["nothing"]).to be_nil
    end

    it "parses bare references as strings" do
      expect(document.instances.first.attributes["ref"]).to eq("OtherInstance")
    end

    it "strips comments" do
      expect(document.instances.first.attributes).not_to include("a")
    end
  end

  context "with lists" do
    let(:source) do
      <<~LML
        instance Style < LabelStyle {
          labellers = ["id:clause_labeller", "id:figure_labeller"]
          templates = [ClauseTemplate, FigureTemplate]
          mixed = ["text", Other, 42]
        }
      LML
    end

    it "parses quoted list items" do
      expect(document.instances.first.attributes["labellers"])
        .to eq(["id:clause_labeller", "id:figure_labeller"])
    end

    it "parses reference list items" do
      expect(document.instances.first.attributes["templates"])
        .to eq(["ClauseTemplate", "FigureTemplate"])
    end

    it "parses mixed list items" do
      expect(document.instances.first.attributes["mixed"])
        .to eq(["text", "Other", 42])
    end
  end

  context "with a nested map" do
    let(:source) do
      <<~LML
        instance T < LabelTemplate {
          pattern = "NOTE %n"
          condition = {
            type = "element_count_gt"
            threshold = 1
          }
        }
      LML
    end

    it "parses the nested map into a hash" do
      expect(document.instances.first.attributes["condition"]).to eq(
        "type" => "element_count_gt", "threshold" => 1
      )
    end
  end

  context "with definition blocks" do
    let(:source) do
      <<~LML
        instance S < LabelStyle {
          definition {
            The ISO/IEC label style originates from:
            * the ISO/IEC Directives, Part 2
            * the ISO House Style.
          }
          short = "one line"
        }
        instance T < LabelStyle {
          definition "inline definition"
        }
      LML
    end

    it "captures multi-line free text verbatim" do
      definition = document.instances.first.attributes["definition"]
      expect(definition).to include("ISO/IEC Directives, Part 2")
      expect(definition).to include("* the ISO House Style.")
    end

    it "keeps slashes inside definition blocks" do
      expect(document.instances.first.attributes["definition"])
        .to include("ISO/IEC")
    end

    it "parses inline string definitions" do
      expect(document.instances.last.attributes["definition"])
        .to eq("inline definition")
    end
  end

  context "with an unbased instance" do
    let(:source) { "instance Foo {\n  x = 1\n}\n" }

    it "parses without a base class" do
      expect(document.instances.first.base).to be_nil
    end
  end

  context "with block comments" do
    let(:source) do
      <<~LML
        /* block
           comment */
        instance Foo < Bar {
          x = 1 // trailing comment
        }
      LML
    end

    it "strips block and trailing comments" do
      expect(document.instances.first.attributes["x"]).to eq(1)
    end
  end

  context "with malformed input" do
    it "raises Ladl::ParseError on a missing brace" do
      expect { described_class.parse("instance Foo < Bar {\n  x = 1\n") }
        .to raise_error(Ladl::ParseError)
    end

    it "raises Ladl::ParseError on stray characters" do
      expect { described_class.parse("$$$") }.to raise_error(Ladl::ParseError)
    end

    it "raises Ladl::ParseError on an unterminated string" do
      expect { described_class.parse(%{instance Foo < Bar {\n  x = "open\n}\n}) }
        .to raise_error(Ladl::ParseError)
    end
  end
end
