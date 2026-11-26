# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the bundled IALA profiles" do
  def el(type, id, children = [])
    Ladl::ContentElement.new(id: id, type: type, children: children)
  end

  describe "the guideline-family profile (G1199 form)" do
    let(:profile) { Ladl.iala_guideline_profile }

    it "loads the IALA guideline label style" do
      expect(profile.style.name).to eq("IALA Guideline Label Style")
    end

    it "labels body clauses with bare dotted numbers" do
      tree = el("document", "doc", [
        el("clause", "c1", [el("subclause", "c1s1", [el("subclause", "c1s1a")])]),
        el("clause", "c2"),
      ])
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      by_id = result.labels_by_element_id
      expect(by_id["c1"].value).to eq("1")
      expect(by_id["c1s1"].value).to eq("1.1")
      expect(by_id["c1s1a"].value).to eq("1.1.1")
      expect(by_id["c2"].value).to eq("2")
    end

    it "numbers figures per chapter (Figure C-N)" do
      tree = el("document", "doc", [
        el("clause", "c1", [el("figure", "f1")]),
        el("clause", "c2"),
        el("clause", "c3", [el("figure", "f2"), el("figure", "f3")]),
      ])
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      by_id = result.labels_by_element_id
      expect(by_id["f1"].value).to eq("Figure 1-1")
      expect(by_id["f2"].value).to eq("Figure 3-1")
      expect(by_id["f3"].value).to eq("Figure 3-2")
    end

    it "renders lone notes bare and repeated notes numbered" do
      tree = el("document", "doc", [
        el("clause", "c1", [el("note", "n1")]),
        el("clause", "c2", [el("note", "n2"), el("note", "n3")]),
      ])
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      by_id = result.labels_by_element_id
      expect(by_id["n1"].value).to eq("NOTE")
      expect(by_id["n2"].value).to eq("NOTE 1")
      expect(by_id["n3"].value).to eq("NOTE 2")
    end

    it "labels annexes Annex A with annex clauses" do
      tree = el("document", "doc", [
        el("annex", "ax", [
          el("clause", "axc1", [el("subclause", "axc1s1")]),
        ]),
      ])
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      by_id = result.labels_by_element_id
      expect(by_id["ax"].value).to eq("Annex A")
      expect(by_id["axc1"].value).to eq("A.1")
      expect(by_id["axc1s1"].value).to eq("A.1.1")
    end
  end

  describe "the standard-family profile (S1040 form)" do
    let(:profile) { Ladl.iala_standard_profile }

    it "loads the IALA standard label style" do
      expect(profile.style.name).to eq("IALA Standard Label Style")
    end

    it "labels clauses with trailing dots" do
      tree = el("document", "doc", [
        el("clause", "c1", [el("subclause", "c1s1")]),
        el("clause", "c2"),
      ])
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      by_id = result.labels_by_element_id
      expect(by_id["c1"].value).to eq("1.")
      expect(by_id["c1s1"].value).to eq("1.1.")
      expect(by_id["c2"].value).to eq("2.")
    end
  end
end
