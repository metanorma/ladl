# frozen_string_literal: true

require "spec_helper"

RSpec.describe "LabelTemplate language variants (MN 112 multilingual)" do
  PROFILE_LML = <<~LML
    instance S < LabelStyle { name = "VariantStyle" contexts = [Doc, ClauseCtx, SubCtx] templates = [ClauseTpl, SubTpl, NoteTpl, NoteGlobalTpl] labellers = ["id:clause_labeller", "id:subclause_labeller", "id:note_labeller"] }
    instance Doc < LabelContext { name = "document" }
    instance ClauseCtx < LabelContext { name = "clause" parent = Doc }
    instance SubCtx < LabelContext { name = "subclause" parent = ClauseCtx }
    instance ClauseTpl < LabelTemplate { pattern = "{clause} %n" }
    instance ClauseLabeller < Labeller {
      id = "clause_labeller"
      sequence = DecimalNumericSequence
      context = Doc
      type = "clause"
      template = ClauseTpl
    }
    instance SubTpl < LabelTemplate { pattern = "%pn.%n" }
    instance SubclauseLabeller < Labeller {
      id = "subclause_labeller"
      sequence = DecimalNumericSequence
      context = ClauseCtx
      parent = ClauseLabeller
      type = "subclause"
      template = SubTpl
    }
    instance NoteTpl < LabelTemplate {
      pattern = "{note_to_entry} %n to entry"
      variants = [NoteTplFr]
    }
    instance NoteTplFr < LabelTemplateVariant {
      lang = "fr"
      pattern = "{note_to_entry} %n à l'article"
    }
    instance NoteGlobalTpl < LabelTemplate {
      pattern = "%parent, {note_to_entry} %n to entry"
      variants = [NoteGlobalTplFr]
    }
    instance NoteGlobalTplFr < LabelTemplateVariant {
      lang = "fr"
      pattern = "%parent, {note_to_entry} %n à l'article"
    }
    instance NoteLabeller < Labeller {
      id = "note_labeller"
      sequence = DecimalNumericSequence
      context = Doc
      type = "note"
      template = NoteTpl
      global_template = NoteGlobalTpl
    }
  LML

  def el(type, id, children = [], context: nil)
    Ladl::ContentElement.new(id: id, type: type, label_context: context,
      children: children)
  end

  let(:tree) do
    el("document", "doc", [
      el("clause", "c1", [
        el("subclause", "e1", [el("note", "e1_n1")]),
        el("note", "c1_n1"),
      ], context: "ClauseCtx"),
    ], context: "Doc")
  end

  it "loads the variant instances and hydrates them on the template" do
    profile = Ladl::ProfileLoader.load_lml(PROFILE_LML)
    template = profile.template("NoteTpl")
    expect(template.variants.map(&:lang)).to eq(["fr"])
    expect(template.variants.first.pattern).to eq("{note_to_entry} %n à l'article")
  end

  it "renders the base pattern when the engine carries no language" do
    result = Ladl::Runtime::Engine.new(Ladl::ProfileLoader.load_lml(PROFILE_LML))
      .label(tree)
    by_id = result.labels_by_element_id
    expect(by_id["e1_n1"].value).to eq("Note 1 to entry")
    expect(by_id["e1_n1"].global_value).to eq("Clause 1, Note 1 to entry")
  end

  it "renders the variant pattern for the engine language" do
    result = Ladl::Runtime::Engine.new(
      Ladl::ProfileLoader.load_lml(PROFILE_LML), lang: "fr",
    ).label(tree)
    by_id = result.labels_by_element_id
    expect(by_id["e1_n1"].value).to eq("Note 1 à l'article")
    expect(by_id["e1_n1"].global_value).to eq("Clause 1, Note 1 à l'article")
  end

  it "falls back to the base pattern for languages without a variant" do
    result = Ladl::Runtime::Engine.new(
      Ladl::ProfileLoader.load_lml(PROFILE_LML), lang: "ru",
    ).label(tree)
    by_id = result.labels_by_element_id
    expect(by_id["e1_n1"].value).to eq("Note 1 to entry")
  end

  it "raises when a template references an undefined variant" do
    broken = <<~LML
      instance S < LabelStyle { name = "Broken" templates = [Tpl] }
      instance Tpl < LabelTemplate { pattern = "%n" variants = [MissingVariant] }
    LML
    expect { Ladl::ProfileLoader.load_lml(broken) }
      .to raise_error(Ladl::ResolutionError, /MissingVariant/)
  end

  it "derives identical instance data from YAML with variants" do
    yaml = <<~YAML
      schema: mn112/1
      instances:
      - name: S
        type: LabelStyle
        properties:
          name: "VariantYaml"
      - name: Tpl
        type: LabelTemplate
        properties:
          pattern: "%n"
          variants:
          - ref: TplFr
      - name: TplFr
        type: LabelTemplateVariant
        properties:
          lang: "fr"
          pattern: "%n (fr)"
    YAML
    profile = Ladl::ProfileLoader.load_yaml(yaml)
    expect(profile.template("Tpl").pattern_for("fr")).to eq("%n (fr)")
    expect(profile.template("Tpl").pattern_for(nil)).to eq("%n")
  end
end
