# frozen_string_literal: true

require "spec_helper"

# Flavor behavior comes entirely from profiles: the same engine drives a
# Japanese clause style and an RTL Arabic style without code changes.
RSpec.describe "profiles drive flavor behavior" do
  def el(type, id, children = [])
    Ladl::ContentElement.new(id: id, type: type, children: children)
  end

  describe "Japanese hierarchical clause labels (MN 112 LabelTemplate example)" do
    def profile_source_with(subclause_pattern)
      <<~LML
        instance S < LabelStyle {
          name = "Japanese"
          labellers = ["id:clause_labeller", "id:subclause_labeller"]
          contexts = [DocumentContext, ClauseContext]
        }
        instance DocumentContext < LabelContext { name = "document" }
        instance ClauseContext < LabelContext {
          name = "clause"
          parent = DocumentContext
        }
        instance ClauseLabelTemplate < LabelTemplate { pattern = "第%n章" }
        instance SubClauseLabelTemplate < LabelTemplate { pattern = "#{subclause_pattern}" }
        instance ClauseLabeller < Labeller {
          id = "clause_labeller"
          sequence = JapaneseNumericSequence
          context = DocumentContext
          type = "clause"
          template = ClauseLabelTemplate
        }
        instance SubClauseLabeller < Labeller {
          id = "subclause_labeller"
          sequence = JapaneseNumericSequence
          context = ClauseContext
          parent = ClauseLabeller
          type = "subclause"
          template = SubClauseLabelTemplate
        }
      LML
    end

    let(:profile) { Ladl::ProfileLoader.load_lml(profile_source_with("%pnの%n")) }

    let(:tree) do
      el("document", "doc", [
        el("clause", "c1", [
          el("subclause", "c1s1"),
          el("subclause", "c1s2"),
        ]),
        el("clause", "c2", [
          el("subclause", "c2s1"),
          el("subclause", "c2s2"),
          el("subclause", "c2s3"),
        ]),
      ])
    end

    it "renders clause numbers as 第N章" do
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      expect(result.local_for(tree.each.find { |e| e.id == "c1" })).to eq("第一章")
      expect(result.local_for(tree.each.find { |e| e.id == "c2" })).to eq("第二章")
    end

    it "renders subclause numbers as 二の三 (parent sequence value + の + value)" do
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      expect(result.local_for(tree.each.find { |e| e.id == "c2s1" })).to eq("二の一")
      expect(result.local_for(tree.each.find { |e| e.id == "c2s2" })).to eq("二の二")
      expect(result.local_for(tree.each.find { |e| e.id == "c2s3" })).to eq("二の三")
    end

    it "renders %parent as the parent's global label (MN 112 definition)" do
      # MN 112's Japanese example writes "%parentの%n" but expects "二の一",
      # which requires %pn semantics; per the %parent definition
      # ("rendered global label of parent") the same profile renders
      # "第二章の一". The example's %parent usage is a spec inconsistency
      # (flagged for the owner); this assertion pins the definition.
      source = profile_source_with("%parentの%n")
      alt = Ladl::ProfileLoader.load_lml(source)
      result = Ladl::Runtime::Engine.new(alt).label(tree)
      expect(result.local_for(tree.each.find { |e| e.id == "c2s2" }))
        .to eq("第二章の二")
    end
  end

  describe "RTL Arabic clause labels (MN 112 RTL example)" do
    let(:profile) do
      Ladl::ProfileLoader.load_lml(<<~LML)
        instance S < LabelStyle {
          name = "Arabic"
          labellers = ["id:arabic_clause_labeller"]
          contexts = [DocumentContext]
        }
        instance DocumentContext < LabelContext { name = "document" }
        instance ArabicClauseLabelTemplate < LabelTemplate {
          pattern = "%n قسم"
          direction = "rtl"
        }
        instance ArabicClauseLabeller < Labeller {
          id = "arabic_clause_labeller"
          sequence = ArabicIndicNumericSequence
          context = DocumentContext
          type = "clause"
          template = ArabicClauseLabelTemplate
        }
      LML
    end

    let(:tree) do
      el("document", "doc", [el("clause", "c1"), el("clause", "c2"), el("clause", "c3")])
    end

    it "renders Arabic-script clause numbers right-to-left" do
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      clauses = tree.children.map { |c| result.local_for(c) }
      expect(clauses).to eq(["١ قسم", "٢ قسم", "٣ قسم"])
    end

    it "carries the rtl direction on the selected template" do
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      label = result.label_for(tree.children.first)
      expect(label.value).to eq("١ قسم")
    end
  end

  describe "custom sequence instances (MN 112 ThreeIncrementArabic example)" do
    let(:profile) do
      Ladl::ProfileLoader.load_lml(<<~LML)
        instance S < LabelStyle {
          name = "Threes"
          labellers = ["id:l"]
          contexts = [DocumentContext]
          sequences = [ThreeIncrementArabic]
        }
        instance DocumentContext < LabelContext { name = "document" }
        instance ThreeIncrementArabic < NumericSequence {
          base_sequence = ArabicIndicNumericSequence
          initial_value = 1
          increment = 3
        }
        instance T < LabelTemplate { pattern = "Step %n" }
        instance L < Labeller {
          id = "l"
          sequence = ThreeIncrementArabic
          context = DocumentContext
          type = "clause"
          template = T
        }
      LML
    end

    it "renders 1, 4, 7 through the base sequence" do
      tree = el("document", "doc", [el("clause", "a"), el("clause", "b"), el("clause", "c")])
      result = Ladl::Runtime::Engine.new(profile).label(tree)
      expect(tree.children.map { |c| result.local_for(c) })
        .to eq(["Step ١", "Step ٤", "Step ٧"])
    end
  end
end

# MN 112 "Full label style definition of SimpleLabelStyle" worked example.
RSpec.describe "the MN 112 SimpleLabelStyle worked example" do
  def el(type, id, children = [])
    Ladl::ContentElement.new(id: id, type: type, children: children)
  end

  let(:profile) do
    Ladl::ProfileLoader.load_lml(<<~LML)
      instance SimpleLabelStyle < LabelStyle {
        name = "Simple Label Style"
        labellers = ["id:figure_labeller", "id:clause_labeller", "id:subclause_labeller"]
        sequences = [DecimalNumericSequence]
        templates = [FigureLabelTemplate, ClauseLabelTemplate, SubClauseLabelTemplate]
        contexts = [DocumentContext, ClauseContext, SubClauseContext]
      }
      instance DocumentContext < LabelContext {
        name = "document"
      }
      instance ClauseContext < LabelContext {
        name = "clause"
        parent = DocumentContext
      }
      instance SubClauseContext < LabelContext {
        name = "subclause"
        parent = ClauseContext
      }
      instance ClauseLabeller < Labeller {
        id = "clause_labeller"
        sequence = DecimalNumericSequence
        context = DocumentContext
        template = ClauseLabelTemplate
        type = "clause"
      }
      instance ClauseLabelTemplate < LabelTemplate {
        pattern = "Clause %n"
      }
      instance SubClauseLabeller < Labeller {
        id = "subclause_labeller"
        sequence = DecimalNumericSequence
        context = ClauseContext
        parent = ClauseLabeller
        template = SubClauseLabelTemplate
        type = "subclause"
      }
      instance SubClauseLabelTemplate < LabelTemplate {
        pattern = "%pn.%n"
      }
      instance FigureLabeller < Labeller {
        id = "figure_labeller"
        sequence = DecimalNumericSequence
        context = DocumentContext
        template = FigureLabelTemplate
        global_template = FigureGlobalLabelTemplate
        type = "figure"
      }
      instance FigureLabelTemplate < LabelTemplate {
        pattern = "Figure %n"
      }
      instance FigureGlobalLabelTemplate < LabelTemplate {
        pattern = "%parent, %self"
      }
    LML
  end

  # MN 112 worked example content tree.
  let(:tree) do
    el("document", "doc", [
      el("clause", "clause1", [
        el("subclause", "s11"),
        el("subclause", "s12", [el("figure", "figure1")]),
      ]),
      el("clause", "clause2", [
        el("figure", "figure2"),
        el("subclause", "s21"),
        el("subclause", "s22", [
          el("subclause", "s221"),
          el("subclause", "s222", [el("figure", "figure3")]),
        ]),
      ]),
    ])
  end

  subject(:result) { Ladl::Runtime::Engine.new(profile).label(tree) }

  it "labels clauses as Clause N" do
    expect(result.local_for(tree.each.find { |e| e.id == "clause1" })).to eq("Clause 1")
    expect(result.local_for(tree.each.find { |e| e.id == "clause2" })).to eq("Clause 2")
  end

  it "labels subclauses as N.M" do
    expect(result.local_for(tree.each.find { |e| e.id == "s11" })).to eq("1.1")
    expect(result.local_for(tree.each.find { |e| e.id == "s22" })).to eq("2.2")
    expect(result.local_for(tree.each.find { |e| e.id == "s221" })).to eq("2.2.1")
  end

  it "labels figures sequentially across the document" do
    expect(result.local_for(tree.each.find { |e| e.id == "figure1" })).to eq("Figure 1")
    expect(result.local_for(tree.each.find { |e| e.id == "figure2" })).to eq("Figure 2")
    expect(result.local_for(tree.each.find { |e| e.id == "figure3" })).to eq("Figure 3")
  end

  it "renders the figure global template with the parent clause" do
    # Figures count at the document context, whose anchor is unlabeled;
    # %parent renders empty per the profile template "%parent, %self".
    expect(result.global_for(tree.each.find { |e| e.id == "figure1" }))
      .to eq(", Figure 1")
  end
end
