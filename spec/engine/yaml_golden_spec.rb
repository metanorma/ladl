# frozen_string_literal: true

require "spec_helper"

# MN 112 golden-tree parity: the worked golden document labels
# identically under the LML and YAML realizations of the ISO/IEC label
# style profile. The profiles are equivalent realizations (MN 112
# "Label style realizations"); the engine consumes either and must
# produce the same labels for the same document tree.
RSpec.describe Ladl::Runtime::Engine, "golden tree under both realizations" do
  lml_profile_path = File.expand_path(
    "../fixtures/iso_iec_label_style_spec_lml.lml", __dir__,
  )
  yaml_profile_path = File.expand_path(
    "../fixtures/iso_iec_label_style_spec_yaml.yaml", __dir__,
  )

  def el(type, id, children = [], context: nil)
    Ladl::ContentElement.new(id: id, type: type, label_context: context,
      children: children)
  end

  let(:tree) do
    el("document", "doc", [
      el("clause", "scope", [el("subclause", "general")],
        context: "ClauseContext"),
      el("clause", "requirements", [
        el("figure", "fig_arch"),
        el("table", "tab_params"),
        el("formula", "form_load"),
        el("list", "list_config", [el("list_item_ordered_level1", "li_a")],
          context: "ListContext"),
        el("note", "note_single"),
      ], context: "ClauseContext"),
      el("clause", "compliance", [el("example", "example_1")],
        context: "ClauseContext"),
      el("annex", "annex_a", [
        el("clause", "annex_a_intro", [
          el("figure", "fig_a1", [el("subfigure", "fig_a1_a")]),
          el("table", "tab_a1"),
        ], context: "AnnexClauseContext"),
      ], context: "AnnexContext"),
      el("annex", "annex_b", [], context: "AnnexContext"),
    ], context: "DocumentContext")
  end

  def labels(path)
    described_class.new(Ladl.load_profile(path)).label(tree)
      .labels_by_element_id.transform_values { |l| [l.value, l.global_value] }
  end

  it "labels the golden tree identically under both realizations" do
    lml_labels = labels(lml_profile_path)
    yaml_labels = labels(yaml_profile_path)

    expect(yaml_labels).to eq(lml_labels)
    expect(lml_labels.keys).to include(
      "scope", "general", "fig_arch", "fig_a1", "fig_a1_a", "annex_a",
    )
  end

  it "labels the main-document clauses in document order" do
    lml_labels = labels(lml_profile_path)

    expect(lml_labels.fetch("scope").first).to eq("1")
    expect(lml_labels.fetch("scope").last).to eq("1")
    expect(lml_labels.fetch("general").first).to eq("1.1")
    expect(lml_labels.fetch("general").last).to eq("1.1")
    expect(lml_labels.fetch("requirements").first).to eq("2")
    expect(lml_labels.fetch("requirements").last).to eq("2")
    expect(lml_labels.fetch("compliance").first).to eq("3")
  end

  it "labels figures, tables and formulas through their sequences" do
    lml_labels = labels(lml_profile_path)

    expect(lml_labels.fetch("fig_arch").first).to start_with("Figure")
    expect(lml_labels.fetch("tab_params").first).to start_with("Table")
    # ISO/IEC formula sequence: unlabeled formulas render "(1)"-style
    # ordinal targets, not "Formula N" captions
    expect(lml_labels.fetch("form_load").first).to eq("(1)")
  end

  it "labels the annex and its children in the annex scheme" do
    lml_labels = labels(lml_profile_path)

    expect(lml_labels.fetch("annex_a").first).to start_with("Annex A")
    expect(lml_labels.fetch("annex_a_intro").first).to start_with("A.1")
    expect(lml_labels.fetch("fig_a1").first).to start_with("Figure A.1")
    expect(lml_labels.fetch("fig_a1_a").first).to eq("Figure A.1 a)")
    expect(lml_labels.fetch("annex_b").first).to start_with("Annex B")
  end

  it "renders the lone note unnumbered" do
    lml_labels = labels(lml_profile_path)

    expect(lml_labels.fetch("note_single").first).to eq("NOTE")
  end

  it "labels the list items through the list context" do
    lml_labels = labels(lml_profile_path)

    expect(lml_labels.fetch("li_a").first).not_to be_nil
    expect(lml_labels.fetch("li_a")).to eq(labels(yaml_profile_path)["li_a"])
  end
end
