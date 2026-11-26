# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the bundled IETF profile" do
  def el(type, id, children = [])
    Ladl::ContentElement.new(id: id, type: type, children: children)
  end

  let(:profile) { Ladl.ietf_profile }

  it "loads the IETF label style" do
    expect(profile.style.name).to eq("IETF Label Style")
  end

  it "references only defined instances" do
    expect { profile }.not_to raise_error
    expect(profile.labeller_names.size).to eq(10)
    expect(profile.template_names.size).to eq(15)
    expect(profile.context_names.size).to eq(5)
  end

  describe "labeling an Internet-Draft tree" do
    let(:tree) do
      el("document", "doc", [
        el("clause", "intro", [
          el("figure", "fig1"),
          el("table", "tab1"),
          el("note", "note1"),
          el("subclause", "conv", [
            el("note", "note2"),
            el("subclause", "conv_deep"),
          ]),
        ]),
        el("annex", "extra", [
          el("clause", "extra_tables", [
            el("figure", "afig"),
            el("table", "atab"),
            el("subclause", "extra_details"),
          ]),
        ]),
      ])
    end

    subject(:result) { Ladl::Runtime::Engine.new(profile).label(tree) }

    let(:by_id) { result.labels_by_element_id }

    it "numbers sections with trailing dots and cites Section N" do
      expect(by_id["intro"].value).to eq("1.")
      expect(by_id["intro"].global_value).to eq("Section 1")
      expect(by_id["conv"].value).to eq("1.1.")
      expect(by_id["conv"].global_value).to eq("Section 1.1")
      expect(by_id["conv_deep"].value).to eq("1.1.1.")
    end

    it "labels appendices Appendix A. and cites Appendix N" do
      expect(by_id["extra"].value).to eq("Appendix A.")
      expect(by_id["extra"].global_value).to eq("Appendix A")
      expect(by_id["extra_tables"].value).to eq("A.1.")
      expect(by_id["extra_tables"].global_value).to eq("Appendix A.1")
      expect(by_id["extra_details"].value).to eq("A.1.1.")
      expect(by_id["extra_details"].global_value).to eq("Appendix A.1.1")
    end

    it "renders caption labels in the xml2rfc colon-caption form" do
      expect(by_id["fig1"].value).to eq("Figure 1")
      expect(by_id["tab1"].value).to eq("Table 1")
      expect(by_id["afig"].value).to eq("Figure A.1")
      expect(by_id["atab"].value).to eq("Table A.1")
    end

    it "renders notes bare and unnumbered" do
      expect(by_id["note1"].value).to eq("Note")
      expect(by_id["note2"].value).to eq("Note")
    end
  end
end
