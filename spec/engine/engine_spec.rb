# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ladl::Runtime::Engine do
  # The worked content tree of MN 112 section "Defining a label style",
  # labeled with the MN 112-A ISO/IEC profile.
  def el(type, id, children = [])
    Ladl::ContentElement.new(id: id, type: type, children: children)
  end

  subject(:result) do
    Ladl::Runtime::Engine.new(Ladl.load_profile(LADL_MN112A_PROFILE)).label(tree)
  end

  let(:locals) { result.labels_by_element_id.transform_values(&:value) }
  let(:globals) { result.labels_by_element_id.transform_values(&:global_value) }

  describe "the golden ISO/IEC tree" do
    let(:tree) do
      el("document", "doc", [
        el("clause", "scope", [
          el("subclause", "general"),
          el("subclause", "normative_refs"),
        ]),
        el("clause", "terms", [
          el("subclause", "terms_general"),
          el("subclause", "defined_terms", [
            el("subclause", "term_def_subclause"),
            el("figure", "fig_flow"),
          ]),
        ]),
        el("clause", "requirements", [
          el("figure", "fig_arch"),
          el("table", "tab_params"),
          el("formula", "form_load"),
          el("list", "list_config", [
            el("list_item_ordered_level1", "li_a"),
            el("list_item_ordered_level1", "li_b"),
          ]),
          el("note", "note_single"),
        ]),
        el("clause", "compliance", [
          el("example", "example_1"),
          el("example", "example_2"),
          el("example", "example_3"),
        ]),
        el("annex", "annex_a", [
          el("clause", "annex_a_intro", [
            el("figure", "fig_a1", [
              el("subfigure", "fig_a1_a"),
              el("subfigure", "fig_a1_b"),
            ]),
            el("table", "tab_a1"),
            el("formula", "form_a1"),
            el("list", "list_a1", [el("list_item_ordered_level1", "li_c")]),
          ]),
          el("clause", "annex_a_spec", []),
        ]),
        el("annex", "annex_b", []),
      ])
    end

    it "labels clauses per the document context" do
      expect(locals["scope"]).to eq("Clause 1")
      expect(locals["terms"]).to eq("Clause 2")
      expect(locals["requirements"]).to eq("Clause 3")
      expect(locals["annex_a_intro"]).to eq("A.1")
    end

    it "labels subclauses hierarchically" do
      expect(locals["general"]).to eq("1.1")
      expect(locals["normative_refs"]).to eq("1.2")
      expect(locals["terms_general"]).to eq("2.1")
      expect(locals["defined_terms"]).to eq("2.2")
      expect(locals["term_def_subclause"]).to eq("2.2.1")
    end

    it "labels annexes with uppercase letters" do
      expect(locals["annex_a"]).to eq("Annex A")
      expect(locals["annex_b"]).to eq("Annex B")
      expect(locals["annex_a_spec"]).to eq("A.2")
    end

    it "labels figures per document in document order, restarting per annex" do
      expect(locals["fig_flow"]).to eq("Figure 1")
      expect(locals["fig_arch"]).to eq("Figure 2")
      expect(locals["fig_a1"]).to eq("Figure A.1")
    end

    it "labels subfigures as Figure A.1 a)" do
      expect(locals["fig_a1_a"]).to eq("Figure A.1 a)")
      expect(locals["fig_a1_b"]).to eq("Figure A.1 b)")
    end

    it "labels tables per document and per annex" do
      expect(locals["tab_params"]).to eq("Table 1")
      expect(locals["tab_a1"]).to eq("Table A.1")
    end

    it "labels formulas locally without the word Formula" do
      expect(locals["form_load"]).to eq("(1)")
      expect(locals["form_a1"]).to eq("(A.1)")
    end

    it "labels formulas globally with the word Formula" do
      expect(globals["form_load"]).to eq("Formula (1)")
      expect(globals["form_a1"]).to eq("Formula (A.1)")
    end

    it "labels lists per clause and per annex" do
      expect(locals["list_config"]).to eq("List 1")
      expect(locals["list_a1"]).to eq("List A.1")
    end

    it "labels ordered list items a) b) restarting per list" do
      expect(locals["li_a"]).to eq("a)")
      expect(locals["li_b"]).to eq("b)")
      expect(locals["li_c"]).to eq("a)")
    end

    it "labels a single note as NOTE" do
      expect(locals["note_single"]).to eq("NOTE")
    end

    it "numbers multiple examples" do
      expect(locals["example_1"]).to eq("EXAMPLE 1")
      expect(locals["example_2"]).to eq("EXAMPLE 2")
      expect(locals["example_3"]).to eq("EXAMPLE 3")
    end

    it "provides global references" do
      expect(globals["scope"]).to eq("Clause 1")
      expect(globals["general"]).to eq("1.1")
      expect(globals["annex_a"]).to eq("Annex A")
      expect(globals["fig_a1"]).to eq("Figure A.1")
      expect(globals["note_single"]).to eq("Clause 3, NOTE")
      expect(globals["example_3"]).to eq("Clause 4, EXAMPLE 3")
      expect(globals["list_config"]).to eq("List 1")
      expect(globals["li_a"]).to eq("a)")
    end

    it "carries sequence values and positions" do
      annex = result.label_for(tree.each.find { |e| e.id == "annex_a" })
      expect(annex.sequence_value).to eq("A")
      expect(annex.position).to eq(1)
      expect(result.label_for(tree.each.find { |e| e.id == "annex_b" }).sequence_value)
        .to eq("B")
    end

    it "does not label the document root" do
      expect(result.label_for(tree)).to be_nil
    end
  end

  describe "alphabet annex expansion (MN 112-A: Annex A, Annex B, ... Annex AA)" do
    let(:children) do
      (1..27).map do |i|
        el("annex", "annex#{i}")
      end
    end
    let(:tree) { el("document", "doc", children) }

    it "labels the 27th annex Annex AA" do
      expect(locals["annex26"]).to eq("Annex Z")
      expect(locals["annex27"]).to eq("Annex AA")
    end
  end

  describe "counter scoping" do
    let(:tree) do
      el("document", "doc", [
        el("clause", "c1", [
          el("subclause", "c1s1", [el("note", "n1"), el("note", "n1b")]),
          el("subclause", "c1s2", [el("note", "n2")]),
        ]),
        el("clause", "c2", [el("note", "n3")]),
      ])
    end

    it "counts notes per section, restarting in each subclause (isodoc note_anchor_names parity)" do
      expect(locals["n1"]).to eq("NOTE 1")
      expect(locals["n1b"]).to eq("NOTE 2")
      expect(locals["n2"]).to eq("NOTE")
      expect(locals["n3"]).to eq("NOTE")
    end

    it "anchors global note references at the enclosing section" do
      expect(globals["n2"]).to eq("1.2, NOTE")
      expect(globals["n3"]).to eq("Clause 2, NOTE")
    end
  end

  describe "figure counters" do
    let(:tree) do
      el("document", "doc", [
        el("clause", "c1", [
          el("figure", "f1", [el("subfigure", "f1a"), el("subfigure", "f1b")]),
        ]),
        el("clause", "c2", [el("figure", "f2", [el("subfigure", "f2a")])]),
      ])
    end

    it "restarts subfigure letters per figure" do
      expect(locals["f1a"]).to eq("Figure 1 a)")
      expect(locals["f1b"]).to eq("Figure 1 b)")
      expect(locals["f2a"]).to eq("Figure 2 a)")
    end
  end

  describe "ordered list nesting" do
    let(:tree) do
      el("document", "doc", [
        el("clause", "c1", [
          el("list", "l1", [
            el("list_item_ordered_level1", "li1", [
              el("list_item_ordered_level2", "li1_1", [
                el("list_item_ordered_level3", "li1_1_1", [
                  el("list_item_ordered_level4", "li1_1_1_1"),
                ]),
              ]),
            ]),
            el("list_item_ordered_level1", "li2", [
              el("list_item_ordered_level2", "li2_1"),
            ]),
          ]),
          el("list", "l2", [el("list_item_ordered_level1", "li3")]),
          el("list", "ul1", [el("list_item_unordered", "ui1")]),
        ]),
      ])
    end

    it "uses the level sequences a) 1) i) a)" do
      expect(locals["li1"]).to eq("a)")
      expect(locals["li1_1"]).to eq("1)")
      expect(locals["li1_1_1"]).to eq("i)")
      expect(locals["li1_1_1_1"]).to eq("a)")
    end

    it "restarts level counters per parent item and per list" do
      expect(locals["li2"]).to eq("b)")
      expect(locals["li2_1"]).to eq("1)")
      expect(locals["li3"]).to eq("a)")
    end

    it "labels unordered list items with dashes at all levels" do
      expect(locals["ui1"]).to eq("—")
    end
  end

  describe "elements without labellers" do
    let(:tree) do
      el("document", "doc", [
        el("clause", "c1", [
          el("paragraph", "p1"),
          el("sourcecode", "sc1"),
        ]),
      ])
    end

    it "traverses unlabeled element types without assigning labels" do
      expect(result.local_for(tree.each.find { |e| e.id == "p1" })).to be_nil
      expect(result.local_for(tree.each.find { |e| e.id == "sc1" })).to be_nil
      expect(result.labels_by_element_id.keys).to eq(["c1"])
    end
  end

  describe "engine construction" do
    it "accepts a resolver as well as a profile" do
      resolver = Ladl::Runtime::Resolver.new(Ladl.load_profile(LADL_MN112A_PROFILE))
      tree = el("document", "doc", [el("clause", "c1")])
      expect(described_class.new(resolver).label(tree).local_for(
        tree.each.find { |e| e.id == "c1" }
      )).to eq("Clause 1")
    end

    it "rejects objects that are not profiles or resolvers" do
      expect { described_class.new("nope") }
        .to raise_error(Ladl::Error, /Profile or Runtime::Resolver/)
    end
  end
end
