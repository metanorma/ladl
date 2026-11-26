# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ladl::Runtime::Engine, "golden tree under both realizations" do
  LADL_MN112A_YAML_PROFILE = File.expand_path("../fixtures/iso_iec_label_style.yaml", __dir__)

  def el(type, id, children = [], context: nil)
    Ladl::ContentElement.new(id: id, type: type, label_context: context,
      children: children)
  end

  let(:tree) do
    el("document", "doc", [
      el("clause", "scope", [el("subclause", "general")], context: "ClauseContext"),
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
      el("annex", "annex_b", []),
    ], context: "DocumentContext")
  end

  def labels(path)
    described_class.new(Ladl.load_profile(path)).label(tree)
      .labels_by_element_id.transform_values { |l| [l.value, l.global_value] }
  end

  it "labels identically from the YAML and lml profiles" do
    expect(labels(LADL_MN112A_YAML_PROFILE)).to eq(labels(LADL_MN112A_PROFILE))
  end

  it "assigns the MN 112 ISO/IEC labels from the YAML profile" do
    by_id = labels(LADL_MN112A_YAML_PROFILE)
    expect(by_id["fig_arch"].first).to eq("Figure 1")
    expect(by_id["annex_b"].first).to eq("Annex B")
    expect(by_id["fig_a1"].first).to eq("Figure A.1")
    expect(by_id["tab_a1"].first).to eq("Table A.1")
  end
end
