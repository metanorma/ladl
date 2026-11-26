# frozen_string_literal: true

module Ladl
  module Adapters
    # Thin duck-typed adapter mapping metanorma-document presentation
    # models onto the LADL content tree (Ladl::ContentElement).
    #
    # The gem does not depend on metanorma-document: elements are
    # recognized by their class name suffix (e.g. "NoteBlock",
    # "HierarchicalSection"), and the adapter accepts any object tree
    # that carries the attributes used here. Flavor models that evolve
    # (e.g. a dedicated Annex section class) are picked up by the name
    # patterns below or by an explicit `annex?`/`ladl_type` method on
    # the element.
    #
    # Element types emitted (matching the ISO/IEC label style profile):
    # "document", "clause", "subclause", "annex", "figure", "table",
    # "note", "example", "formula", "list", "list_item_unordered",
    # "list_item_ordered_level1".."list_item_ordered_level4". Unlabeled
    # kinds (paragraphs, titles, sourcecode blocks, ...) map to their
    # underscored class name and are traversed but never labeled, since
    # no labeller in a profile binds their type.
    class MetanormaDocument
      BLOCK_TYPES = {
        "NoteBlock" => "note",
        "ExampleBlock" => "example",
        "FormulaBlock" => "formula",
        "FigureBlock" => "figure",
        "TableBlock" => "table",
      }.freeze

      SECTION_CLASSES = %w[HierarchicalSection BasicSection ContentSection
        ReferencesSection].freeze
      LIST_CLASSES = %w[OrderedList UnorderedList].freeze
      LIST_ITEM_CLASSES = %w[ListItem].freeze
      LIST_ITEM_CHILD_METHODS = %i[ordered_lists unordered_lists figure
        formula note example table sourcecode].freeze
      FIGURE_CHILD_METHODS = %i[figure].freeze
      ROOT_CHILD_METHODS = %i[sections annexes preface].freeze

      class << self
        # Builds a Ladl::ContentElement tree from a metanorma-document
        # presentation root.
        def wrap(root)
          new.build(root)
        end
      end

      def build(element, section_depth: 0, list_depth: 0, annex: false,
        ordered: false, figure_child: false)
        type = element_type(element, section_depth, annex, ordered, figure_child)
        content = Ladl::ContentElement.new(id: element_id(element), type: type)
        child_params = next_params(type, element, section_depth, list_depth, annex)
        children_of(element).each do |child|
          content.add_child(build(child, **child_params))
        end
        content
      end

      private

      def element_type(element, section_depth, annex, ordered, figure_child)
        explicit = element.respond_to?(:ladl_type) ? element.ladl_type : nil
        return explicit if explicit

        name = class_name(element)
        case name
        when "Root", "DocumentRoot"
          "document"
        when *LIST_CLASSES
          "list"
        when *LIST_ITEM_CLASSES
          list_item_type(ordered)
        when *SECTION_CLASSES
          section_type(section_depth)
        when "FigureBlock"
          figure_child ? "subfigure" : "figure"
        when *BLOCK_TYPES.keys
          BLOCK_TYPES.fetch(name)
        else
          if annex_section?(element)
            "annex"
          else
            underscore(name)
          end
        end
      end

      # depth 0 within the current scope: a main-document top-level
      # section is a "clause", deeper sections are "subclauses"; inside
      # an annex, the depth restarts, so annex clauses are "clause"
      # again (the AnnexClauseLabeller picks them up through the annex
      # context).
      def section_type(depth)
        depth.zero? ? "clause" : "subclause"
      end

      def list_item_type(ordered)
        if ordered.to_i.positive?
          "list_item_ordered_level#{level_of(ordered)}"
        else
          "list_item_unordered"
        end
      end

      # The ordered-list nesting depth is passed down as `ordered` (an
      # Integer, 0 for unordered); levels wrap every four levels,
      # repeating the first level's scheme (MN 112-A ordered list items:
      # a) 1) i) a) ...).
      def level_of(ordered)
        ((ordered - 1) % 4) + 1
      end

      def annex_section?(element)
        return true if element.respond_to?(:annex?) && element.annex?

        class_name(element) =~ /Annex/ ? true : false
      end

      def class_name(element)
        element.class.name&.split("::")&.last.to_s
      end

      def element_id(element)
        if element.respond_to?(:id) && element.id
          element.id
        elsif element.respond_to?(:anchor) && element.anchor
          element.anchor
        end
      end

      def underscore(name)
        name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
      end

      # Returns the params hash for the recursive child build.
      def next_params(type, element, section_depth, list_depth, annex)
        case type
        when "document"
          { section_depth: 0, list_depth: 0, annex: false, ordered: false,
            figure_child: false }
        when "clause", "subclause"
          { section_depth: section_depth + 1, list_depth: 0, annex: annex,
            ordered: false, figure_child: false }
        when "annex"
          { section_depth: 0, list_depth: 0, annex: true, ordered: false,
            figure_child: false }
        when "list"
          { section_depth: section_depth, list_depth: list_depth + 1,
            annex: annex,
            ordered: class_name(element) == "OrderedList" ? list_depth + 1 : 0,
            figure_child: false }
        when "figure"
          { section_depth: section_depth, list_depth: list_depth,
            annex: annex, ordered: false, figure_child: true }
        else
          { section_depth: section_depth, list_depth: list_depth,
            annex: annex, ordered: false, figure_child: false }
        end
      end

      # Child accessor per element kind; metanorma-document keeps
      # children in kind-specific collections, visited in document
      # order: blocks (with their nested notes), section notes, then
      # subsections.
      def children_of(element)
        return Array(element.children) if element.respond_to?(:children)

        name = class_name(element)
        if SECTION_CLASSES.include?(name) || name == "Sections" ||
            name =~ /Annex/
          section_children(element)
        elsif LIST_CLASSES.include?(name)
          Array(element.listitem)
        elsif LIST_ITEM_CLASSES.include?(name)
          via_methods(element, LIST_ITEM_CHILD_METHODS)
        elsif name == "FigureBlock"
          via_methods(element, FIGURE_CHILD_METHODS)
        elsif %w[Root DocumentRoot Document].include?(name)
          via_methods(element, ROOT_CHILD_METHODS)
        else
          via_methods(element, %i[notes])
        end
      end

      def section_children(element)
        children = []
        # The standoc-style Sections container keeps clauses in
        # kind-specific collections (clause, introduction, terms,
        # definitions, references, floating_title) in document order.
        if class_name(element) == "Sections"
          %i[introduction clause terms definitions references
            floating_title].each do |collection|
            if element.respond_to?(collection)
              Array(element.public_send(collection)).each do |c|
                children << c
              end
            end
          end
          return children
        end
        Array(element.blocks).each do |block|
          children << block
          Array(block.notes).each { |n| children << n } if block.respond_to?(:notes)
        end
        if element.respond_to?(:notes)
          Array(element.notes).each { |n| children << n }
        end
        if element.respond_to?(:subsections)
          Array(element.subsections).each { |s| children << s }
        end
        children
      end

      def via_methods(element, methods)
        children = []
        methods.each do |method|
          if element.respond_to?(method)
            Array(element.public_send(method)).each { |c| children << c }
          end
        end
        children
      end
    end
  end
end
