# frozen_string_literal: true

require "spec_helper"

# MN 112 label catalogs: catalog values are Fluent message patterns
# resolved by the rhoella engine. Plain values stay plain words;
# designations that need engine values carry `{ $n }`, `{ $pn }`,
# `{ $parent }` and `{ $self }` placeables bound from the labeller
# bindings. Language selection is catalog selection: the host hands
# the message catalog for its language, the profile stays unchanged.
RSpec.describe "Fluent message catalogs" do
  def el(type, id, children = [], context: nil)
    Ladl::ContentElement.new(id: id, type: type, label_context: context,
      children: children)
  end

  let(:tree) do
    el("document", "doc", [
      el("clause", "c1", [
        el("subclause", "e1", [el("note", "e1_n1")], context: "TermEntryContext"),
      ], context: "ClauseContext"),
    ], context: "DocumentContext")
  end

  let(:profile) { Ladl.load_profile(LADL_MN112A_PROFILE) }

  it "renders the English default catalog unchanged" do
    result = Ladl::Runtime::Engine.new(profile).label(tree)
    label = result.labels_by_element_id["e1_n1"]
    expect(label.value).to eq("Note 1 to entry")
    expect(label.global_value).to eq("1.1, Note 1 to entry")
  end

  it "renders the French catalog message, whose structure embeds the parent" do
    result = Ladl::Runtime::Engine.new(profile, labels: {
      "note_to_entry" => "Note { $n } à l'article",
      "note_to_entry_xref" => "Note { $n } à l'article { $parent }",
    }).label(tree)
    label = result.labels_by_element_id["e1_n1"]
    expect(label.value).to eq("Note 1 à l'article")
    expect(label.global_value).to eq("Note 1 à l'article 1.1")
  end

  it "resolves plain word messages unchanged" do
    tree = el("document", "doc", [el("clause", "c1")], context: "DocumentContext")
    result = Ladl::Runtime::Engine.new(profile, labels: {
      "clause" => "Article",
    }).label(tree)
    expect(result.labels_by_element_id["c1"].value).to eq("Article 1")
  end

  it "wraps catalog rendering failures as resolution errors" do
    broken = el("document", "doc", [el("clause", "c1")], context: "DocumentContext")
    expect {
      Ladl::Runtime::Engine.new(profile, labels: {
        "clause" => "Article { nowhere_message }",
      }).label(broken)
    }.to raise_error(Ladl::ResolutionError, /{clause}.*failed to render/)
  end

  it "renders message references inside catalog messages" do
    tree = el("document", "doc", [el("clause", "c1")], context: "DocumentContext")
    result = Ladl::Runtime::Engine.new(profile, labels: {
      "clause_word" => "Article",
      "clause" => "{ clause_word }",
    }).label(tree)
    expect(result.labels_by_element_id["c1"].value).to eq("Article 1")
  end
end
