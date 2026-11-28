# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ladl::ProfileLoader do
  describe ".load_file with the bundled ISO/IEC profile" do
    subject(:profile) { described_class.load_file(LADL_MN112A_PROFILE) }

    it "loads the ISO/IEC label style" do
      expect(profile.style.name).to eq("ISO/IEC Label Style")
    end

    it "captures the style definition text" do
      expect(profile.style.definition).to include("ISO/IEC Directives, Part 2")
    end

    it "loads 31 labellers" do
      expect(profile.labeller_names.size).to eq(31)
    end

    it "loads 11 contexts" do
      expect(profile.context_names.size).to eq(11)
    end

    it "loads 49 label templates" do
      expect(profile.template_names.size).to eq(49)
    end

    it "hydrates the clause labeller with nested templates" do
      labeller = profile.labeller("ClauseLabeller")
      expect(labeller.id).to eq("clause_labeller")
      expect(labeller.type).to eq("clause")
      expect(labeller.context).to eq("DocumentContext")
      expect(labeller.sequence).to eq("DecimalNumericSequence")
      expect(labeller.template.first.pattern).to eq("{clause} %n")
      expect(labeller.global_template.first.pattern).to eq("{clause} %n")
    end

    it "hydrates the subclause labeller with its parent labeller" do
      labeller = profile.labeller("SubclauseLabeller")
      expect(labeller.parent).to eq("ClauseLabeller")
      expect(labeller.template.first.pattern).to eq("%pn.%n")
    end

    it "hydrates the note labeller with conditional templates" do
      labeller = profile.labeller("NoteLabeller")
      single, multiple = labeller.template
      expect(single.pattern).to eq("{note}")
      expect(single.condition).to be_nil
      expect(multiple.pattern).to eq("{note} %n")
      expect(multiple.condition.type).to eq("element_count_gt")
      expect(multiple.condition.threshold).to eq(1)
    end

    it "hydrates contexts with parent links" do
      clause = profile.context("ClauseContext")
      expect(clause.name).to eq("clause")
      expect(clause.parent).to eq("DocumentContext")
      annex_clause = profile.context("AnnexClauseContext")
      expect(annex_clause.parent).to eq("AnnexContext")
    end

    it "does not define profile-local sequences (they are registry defaults)" do
      expect(profile.sequence_names).to be_empty
    end
  end

  describe ".load_lml" do
    it "builds a profile from inline .lml text" do
      source = <<~LML
        instance S < LabelStyle {
          name = "Tiny"
          labellers = ["id:l1"]
          contexts = [Ctx]
          templates = [Tpl]
          sequences = [DecimalNumericSequence]
        }
        instance Ctx < LabelContext {
          name = "document"
        }
        instance Tpl < LabelTemplate {
          pattern = "C %n"
        }
        instance L1 < Labeller {
          id = "l1"
          sequence = DecimalNumericSequence
          context = Ctx
          type = "clause"
          template = Tpl
        }
      LML
      profile = described_class.load_lml(source)
      expect(profile.style.name).to eq("Tiny")
      expect(profile.labeller("L1").template.first.pattern).to eq("C %n")
    end

    it "raises Ladl::ParseError when no LabelStyle is present" do
      source = "instance Ctx < LabelContext {\n  name = \"document\"\n}\n"
      expect { described_class.load_lml(source) }
        .to raise_error(Ladl::ParseError, /no LabelStyle/)
    end

    it "raises Ladl::ParseError on an unknown base class" do
      source = "instance X < NotALadlClass {\n  x = 1\n}\n"
      expect { described_class.load_lml(source) }
        .to raise_error(Ladl::ParseError, /unknown base class/)
    end

    it "raises Ladl::ParseError on a base-less instance" do
      source = "instance X {\n  x = 1\n}\n"
      expect { described_class.load_lml(source) }
        .to raise_error(Ladl::ParseError, /declares no base class/)
    end

    it "raises Ladl::ParseError on duplicate instance names" do
      source = <<~LML
        instance A < LabelContext { name = "one" }
        instance A < LabelContext { name = "two" }
      LML
      expect { described_class.load_lml(source) }
        .to raise_error(Ladl::ParseError, /duplicate instance/)
    end

    it "raises Ladl::ResolutionError when a labeller references an undefined template" do
      source = <<~LML
        instance S < LabelStyle { name = "S" }
        instance L < Labeller {
          id = "l"
          context = MissingContext
          type = "clause"
          template = MissingTemplate
        }
      LML
      expect { described_class.load_lml(source) }
        .to raise_error(Ladl::ResolutionError, /MissingTemplate/)
    end

    it "hydrates inline template objects given in place of references" do
      source = <<~LML
        instance S < LabelStyle { name = "S" }
        instance L < Labeller {
          id = "l"
          context = C
          type = "clause"
          template = {
            pattern = "Inline %n"
          }
        }
        instance C < LabelContext { name = "clause" }
      LML
      profile = described_class.load_lml(source)
      expect(profile.labeller("L").template.first.pattern).to eq("Inline %n")
    end

    it "loads profile-defined sequence instances" do
      source = <<~LML
        instance S < LabelStyle { name = "S" sequences = [Triple] }
        instance Triple < NumericSequence {
          base_sequence = DecimalNumericSequence
          initial_value = 1
          increment = 3
        }
      LML
      profile = described_class.load_lml(source)
      expect(profile.sequence("Triple").increment).to eq(3)
    end

    it "hydrates ContentElement and Label instances" do
      source = <<~LML
        instance S < LabelStyle { name = "S" }
        instance E < ContentElement {
          id = "e1"
          type = "clause"
        }
        instance Label1 < Label {
          value = "Clause 1"
          content_element = e1
        }
      LML
      profile = described_class.load_lml(source)
      expect(profile.element("E").type).to eq("clause")
      expect(profile.label("Label1").value).to eq("Clause 1")
    end
  end

  describe "Ladl.load_profile with the MN 112-A worked profile" do
    it "exposes the profile loader at the root module" do
      expect(Ladl.load_profile(LADL_MN112A_PROFILE)).to be_a(Ladl::Profile)
      expect(Ladl.load_profile(LADL_MN112A_PROFILE).style.name)
        .to eq("ISO/IEC Label Style")
    end
  end
end
