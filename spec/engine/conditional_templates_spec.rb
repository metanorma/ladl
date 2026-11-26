# frozen_string_literal: true

require "spec_helper"

RSpec.describe "conditional label templates (MN 112 LabelContextCondition)" do
  def el(type, id, children = [], context: nil)
    Ladl::ContentElement.new(id: id, type: type, label_context: context,
      children: children)
  end

  def note_profile
    Ladl.load_profile(LADL_MN112A_PROFILE)
  end

  it "uses the numbered template when the context has more than one note" do
    tree = el("document", "doc", [
      el("clause", "c1", [el("note", "n1"), el("note", "n2")],
        context: "ClauseContext"),
    ], context: "DocumentContext")
    result = Ladl::Runtime::Engine.new(note_profile).label(tree)
    expect(result.local_for(tree.each.find { |e| e.id == "n1" })).to eq("NOTE 1")
    expect(result.local_for(tree.each.find { |e| e.id == "n2" })).to eq("NOTE 2")
  end

  it "uses the unnumbered template for a single note" do
    tree = el("document", "doc", [
      el("clause", "c1", [el("note", "n1")], context: "ClauseContext"),
    ], context: "DocumentContext")
    result = Ladl::Runtime::Engine.new(note_profile).label(tree)
    expect(result.local_for(tree.each.find { |e| e.id == "n1" })).to eq("NOTE")
  end

  it "does the same for examples" do
    tree = el("document", "doc", [
      el("clause", "c1", [el("example", "e1")], context: "ClauseContext"),
      el("clause", "c2", [el("example", "e2"), el("example", "e3")],
        context: "ClauseContext"),
    ], context: "DocumentContext")
    result = Ladl::Runtime::Engine.new(note_profile).label(tree)
    expect(result.local_for(tree.each.find { |e| e.id == "e1" })).to eq("EXAMPLE")
    expect(result.local_for(tree.each.find { |e| e.id == "e2" })).to eq("EXAMPLE 1")
    expect(result.local_for(tree.each.find { |e| e.id == "e3" })).to eq("EXAMPLE 2")
  end

  it "selects the first matching template when conditions overlap" do
    source = <<~LML
      instance S < LabelStyle {
        name = "Overlap"
        labellers = ["id:n"]
        contexts = [DocumentContext]
        templates = [Tgt, Teq]
      }
      instance DocumentContext < LabelContext { name = "document" }
      instance Tgt < LabelTemplate {
        pattern = "GT %n"
        condition = { type = "element_count_gt"  threshold = 1 }
      }
      instance Teq < LabelTemplate {
        pattern = "EQ %n"
        condition = { type = "element_count_eq"  threshold = 2 }
      }
      instance N < Labeller {
        id = "n"
        sequence = DecimalNumericSequence
        context = DocumentContext
        type = "note"
        template = [Tgt, Teq]
      }
    LML
    profile = Ladl::ProfileLoader.load_lml(source)
    tree = el("document", "doc", [el("note", "x1"), el("note", "x2")], context: "DocumentContext")
    result = Ladl::Runtime::Engine.new(profile).label(tree)
    # both conditions match at count 2; the first (GT) wins
    expect(result.local_for(tree.each.find { |e| e.id == "x1" })).to eq("GT 1")
  end

  it "falls back to the first template when all conditions fail" do
    source = <<~LML
      instance S < LabelStyle {
        name = "Fallback"
        labellers = ["id:n"]
        contexts = [DocumentContext]
        templates = [Teq]
      }
      instance DocumentContext < LabelContext { name = "document" }
      instance Teq < LabelTemplate {
        pattern = "EQ %n"
        condition = { type = "element_count_eq"  threshold = 5 }
      }
      instance N < Labeller {
        id = "n"
        sequence = DecimalNumericSequence
        context = DocumentContext
        type = "note"
        template = Teq
      }
    LML
    profile = Ladl::ProfileLoader.load_lml(source)
    tree = el("document", "doc", [el("note", "x1")], context: "DocumentContext")
    result = Ladl::Runtime::Engine.new(profile).label(tree)
    expect(result.local_for(tree.each.find { |e| e.id == "x1" })).to eq("EQ 1")
  end

  it "raises a resolution error for a labeller without templates" do
    source = <<~LML
      instance S < LabelStyle {
        name = "NoTemplate"
        labellers = ["id:n"]
        contexts = [DocumentContext]
      }
      instance DocumentContext < LabelContext { name = "document" }
      instance N < Labeller {
        id = "n"
        sequence = DecimalNumericSequence
        context = DocumentContext
        type = "note"
      }
    LML
    profile = Ladl::ProfileLoader.load_lml(source)
    tree = el("document", "doc", [el("note", "x1")], context: "DocumentContext")
    expect { Ladl::Runtime::Engine.new(profile).label(tree) }
      .to raise_error(Ladl::ResolutionError, /no label template/)
  end
end
