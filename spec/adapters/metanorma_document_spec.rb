# frozen_string_literal: true

# Minimal stubs mirroring metanorma-document presentation classes. The
# adapter duck-types on class name suffixes, so these stand-ins exercise
# the real adapter logic without depending on metanorma-document.
module MetanormaStubs
  class Root
    attr_accessor :sections

    def initialize(sections = [])
      @sections = sections
    end
  end

  class HierarchicalSection
    attr_accessor :id, :title, :blocks, :notes, :subsections

    def initialize(id:, blocks: [], notes: [], subsections: [], title: nil)
      @id = id
      @title = title
      @blocks = blocks
      @notes = notes
      @subsections = subsections
    end
  end

  class AnnexSection < HierarchicalSection; end

  class NoteBlock
    attr_accessor :id

    def initialize(id)
      @id = id
    end
  end

  class ExampleBlock < NoteBlock; end
  class FormulaBlock < NoteBlock; end
  class TableBlock < NoteBlock; end

  class FigureBlock
    attr_accessor :id, :figure

    def initialize(id, figure = [])
      @id = id
      @figure = figure
    end
  end

  class OrderedList
    attr_accessor :id, :listitem

    def initialize(id, listitem = [])
      @id = id
      @listitem = listitem
    end
  end

  class UnorderedList < OrderedList; end

  class ListItem
    attr_accessor :id, :ordered_lists, :unordered_lists

    def initialize(id, ordered_lists: [], unordered_lists: [])
      @id = id
      @ordered_lists = ordered_lists
      @unordered_lists = unordered_lists
    end
  end
end

require "spec_helper"

RSpec.describe Ladl::Adapters::MetanormaDocument do
  describe ".wrap" do
    let(:tree) do
      MetanormaStubs::Root.new([
        MetanormaStubs::HierarchicalSection.new(
          id: "sec1",
          blocks: [
            MetanormaStubs::NoteBlock.new("note1"),
            MetanormaStubs::FigureBlock.new("fig1", [
              MetanormaStubs::FigureBlock.new("fig1a"),
            ]),
            MetanormaStubs::TableBlock.new("tab1"),
            MetanormaStubs::FormulaBlock.new("form1"),
            MetanormaStubs::OrderedList.new("ol1", [
              MetanormaStubs::ListItem.new("li1",
                ordered_lists: [MetanormaStubs::OrderedList.new("ol2", [
                  MetanormaStubs::ListItem.new("li1_1"),
                  MetanormaStubs::ListItem.new("li1_2"),
                ])]),
              MetanormaStubs::ListItem.new("li2"),
            ]),
            MetanormaStubs::UnorderedList.new("ul1", [
              MetanormaStubs::ListItem.new("uli1"),
            ]),
            MetanormaStubs::ExampleBlock.new("ex1"),
          ],
          notes: [MetanormaStubs::NoteBlock.new("note2")],
          subsections: [
            MetanormaStubs::HierarchicalSection.new(id: "sec1_1"),
          ],
        ),
        MetanormaStubs::AnnexSection.new(
          id: "anx",
          blocks: [MetanormaStubs::FigureBlock.new("afig")],
          subsections: [],
        ),
      ])
    end

    subject(:wrapped) { described_class.wrap(tree) }

    def type_of(id)
      wrapped.each.find { |e| e.id == id }&.type
    end

    it "maps the root to document" do
      expect(wrapped.type).to eq("document")
    end

    it "maps top-level sections to clause and deeper sections to subclause" do
      expect(type_of("sec1")).to eq("clause")
      expect(type_of("sec1_1")).to eq("subclause")
    end

    it "maps annex classes to annex" do
      expect(type_of("anx")).to eq("annex")
    end

    it "maps block classes to LADL types" do
      expect(type_of("note1")).to eq("note")
      expect(type_of("ex1")).to eq("example")
      expect(type_of("form1")).to eq("formula")
      expect(type_of("tab1")).to eq("table")
      expect(type_of("fig1")).to eq("figure")
    end

    it "maps nested figure blocks to subfigures" do
      expect(type_of("fig1a")).to eq("subfigure")
    end

    it "maps ordered list items with nesting levels" do
      expect(type_of("li1")).to eq("list_item_ordered_level1")
      expect(type_of("li1_1")).to eq("list_item_ordered_level2")
      expect(type_of("li1_2")).to eq("list_item_ordered_level2")
      expect(type_of("li2")).to eq("list_item_ordered_level1")
    end

    it "maps unordered list items to the unordered type" do
      expect(type_of("uli1")).to eq("list_item_unordered")
    end

    it "keeps annex figures as figures (the annex context labels them)" do
      expect(type_of("afig")).to eq("figure")
    end
  end

  describe "end-to-end through the ISO/IEC profile" do
    let(:tree) do
      MetanormaStubs::Root.new([
        MetanormaStubs::HierarchicalSection.new(
          id: "c1",
          blocks: [
            MetanormaStubs::FigureBlock.new("f1"),
            MetanormaStubs::NoteBlock.new("n1"),
          ],
          subsections: [
            MetanormaStubs::HierarchicalSection.new(
              id: "c1s1", blocks: [MetanormaStubs::NoteBlock.new("n2")]
            ),
          ],
        ),
        MetanormaStubs::AnnexSection.new(
          id: "anxA",
          blocks: [MetanormaStubs::TableBlock.new("t1")],
          subsections: [
            MetanormaStubs::HierarchicalSection.new(
              id: "a1", blocks: [MetanormaStubs::FigureBlock.new("fa1")]
            ),
          ],
        ),
      ])
    end

    it "labels the stubbed metanorma-document tree per ISO/IEC conventions" do
      wrapped = described_class.wrap(tree)
      result = Ladl::Runtime::Engine.new(Ladl.iso_iec_profile).label(wrapped)
      by_id = result.labels_by_element_id
      expect(by_id["c1"].value).to eq("Clause 1")
      expect(by_id["c1s1"].value).to eq("1.1")
      expect(by_id["f1"].value).to eq("Figure 1")
      expect(by_id["anxA"].value).to eq("Annex A")
      expect(by_id["a1"].value).to eq("A.1")
      expect(by_id["fa1"].value).to eq("Figure A.1")
      expect(by_id["t1"].value).to eq("Table A.1")
      expect(by_id["n1"].value).to eq("NOTE 1")
      expect(by_id["n1"].global_value).to eq("Clause 1, NOTE 1")
      expect(by_id["n2"].value).to eq("NOTE 2")
    end
  end

  describe "custom type overrides" do
    it "honors a ladl_type method on elements" do
      custom = Class.new do
        attr_accessor :id

        def initialize(id)
          @id = id
        end

        def ladl_type
          "clause"
        end
      end
      element = custom.new("x")
      wrapped = described_class.wrap(element)
      expect(wrapped.type).to eq("clause")
    end

    it "honors an annex? method on elements" do
      custom = Class.new do
        attr_accessor :id

        def initialize(id)
          @id = id
        end

        def annex?
          true
        end
      end
      wrapped = described_class.wrap(custom.new("anx"))
      expect(wrapped.type).to eq("annex")
    end
  end
end
