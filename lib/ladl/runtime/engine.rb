# frozen_string_literal: true

module Ladl
  module Runtime
    # The LADL labeling engine: evaluates a resolved label style against
    # a content tree, producing a Ladl::Label per labeled element.
    #
    # The engine implements the MN 112 algorithm to resolve the label
    # for a content element:
    #
    # 1. Walk the content tree depth-first, maintaining a stack of
    #    label context instances (the context tree, instantiated) and a
    #    stack of labeled element entries (for `%pn`/`%parent`
    #    resolution).
    # 2. For each element, find the labeller bound to the nearest
    #    enclosing context instance that can label the element type.
    # 3. Instantiate the label context the element opens, per the
    #    profile (a context whose parent is the labeller's context, or
    #    one named after the element type).
    # 4. Increment the labeller's counter within the context instance
    #    the labeller is bound to, scoped by the parent element when the
    #    labeller has a parent labeller.
    # 5. Select the label template: the first whose
    #    LabelContextCondition evaluates to true against the total count
    #    of similar elements in the same context (MN 112 conditional
    #    templates); fall back to the first unconditional template.
    # 6. Render the template pattern with string interpolation.
    #
    # The walk runs first (planning + counting), then labels are
    # rendered, so conditional templates see final sibling counts.
    class Engine
      # A label context instance: the runtime instantiation of a
      # LabelContext definition. Counters are keyed by
      # [frame path, labeller name, parent scope].
      Frame = Struct.new(:instance_name, :path, :counters, :anchor_entry,
        keyword_init: true)

      # A labeled element planned during the walk.
      Entry = Struct.new(:element, :type, :labeller, :labeller_name, :frame,
        :key, :position, :raw_value, :parent_hier, :parent_frame,
        :hierarchical, :local, :global,
        keyword_init: true)

      attr_reader :result, :resolved

      # @param resolved [Runtime::Resolver, Ladl::Profile] a resolved
      #   label style, or a profile to resolve
      # @param labels [Hash{String => String}] the label vocabulary for
      #   `{key}` tokens in template patterns — the host document's i18n
      #   table (e.g. annex: "Annexe"); keys absent from the dictionary
      #   fall back to the English default vocabulary
      def initialize(resolved, labels: {})
        @labels = labels || {}
        @resolved = case resolved
        when Runtime::Resolver
          resolved
        when Ladl::Profile
          Runtime::Resolver.new(resolved)
        else
          raise Ladl::Error,
            "engine requires a Ladl::Profile or Runtime::Resolver, " \
            "got #{resolved.class}"
        end
        @frames = []
        @entries = []
        @plan = []
        @totals = {}
        @frame_seq = 0
        @result = Result.new
      end

      # Labels the content tree rooted at `root` and returns the
      # Ladl::Runtime::Result.
      def label(root)
        walk(root)
        render
        @result
      end
      alias label_document label

      private

      def walk(element)
        type = element.type.to_s
        labeller, counter_frame = resolve_labeller(type)
        frame = open_frame(type, labeller, element)
        entry = plan_element(element, labeller, counter_frame) if labeller
        frame.anchor_entry = entry if frame
        children_of(element).each { |child| walk(child) }
        @entries.pop if entry
        @frames.pop if frame
      end

      def children_of(element)
        return [] unless element.respond_to?(:children)

        Array(element.children)
      end

      # MN 112 algorithm step 2: the labeller bound to the nearest
      # enclosing context instance that can label this element type.
      # Returns [labeller, frame the labeller's counters live in].
      def resolve_labeller(type)
        @frames.reverse_each do |frame|
          labeller = @resolved.labeller_for_context(frame.instance_name, type)
          return [labeller, frame] if labeller
        end
        [nil, nil]
      end

      # MN 112 algorithm step 3: the label context instance this element
      # opens, if any. Preference order: a child context of the
      # element's labeller context matching the element type; a unique
      # child context of the element's labeller context not already
      # active; a context named after the element type.
      def open_frame(type, labeller, element)
        candidate = nil
        if labeller
          child_contexts = @resolved.contexts_with_parent(labeller.context)
          named = child_contexts.select do |name|
            @resolved.context_name(name) == type
          end
          if named.size == 1
            candidate = named.first
          elsif child_contexts.size == 1 && !active?(child_contexts.first)
            candidate = child_contexts.first
          end
        end
        candidate ||= top_level_named(type)
        return nil unless candidate

        @frame_seq += 1
        frame = Frame.new(
          instance_name: candidate,
          path: "#{@frames.last ? @frames.last.path : ""}/#{candidate}[#{@frame_seq}]",
          counters: Hash.new(0),
        )
        @frames.push(frame)
        frame
      end

      def active?(instance_name)
        @frames.any? { |f| f.instance_name == instance_name }
      end

      def top_level_named(type)
        named = @resolved.contexts_named(type)
        named.size == 1 ? named.first : nil
      end

      def plan_element(element, labeller, counter_frame)
        parent = find_parent_entry(labeller)
        parent_hier = parent&.hierarchical
        position = increment_counter(counter_frame, labeller, parent_hier)
        raw = sequence_raw(labeller, position)
        entry = Entry.new(
          element: element,
          type: element.type.to_s,
          labeller: labeller,
          labeller_name: @resolved.instance_name_of(labeller),
          frame: counter_frame,
          key: [counter_frame.path, @resolved.instance_name_of(labeller),
            parent_hier.to_s],
          position: position,
          raw_value: raw,
          parent_hier: parent_hier,
          parent_frame: counter_frame,
          hierarchical: join_hierarchical(parent_hier, raw),
        )
        @entries.push(entry)
        @plan << entry
        entry
      end

      # The nearest enclosing labeled element that supplies the `%pn`
      # value and the hierarchical counter scope for this labeller:
      # the nearest entry labeled by a labeller in this labeller's
      # self-inclusive ancestor chain (the enclosing subclause for
      # 1.2.1, the enclosing annex for Figure A.1, the containing list
      # item for a nested list item). Falls back to the nearest entry
      # of the parent labeller's element type (e.g. an enclosing figure
      # labeled by the annex figure labeller for a subfigure).
      def find_parent_entry(labeller)
        parent_name = labeller.parent
        return nil if parent_name.nil? || parent_name.empty?

        parent_labeller = @resolved.profile.labeller(parent_name)
        unless parent_labeller
          raise Ladl::ResolutionError,
            "labeller #{@resolved.instance_name_of(labeller).inspect} " \
            "references undefined parent labeller #{parent_name.inspect}"
        end
        chain = @resolved.ancestor_chain(@resolved.instance_name_of(labeller))
        @entries.reverse_each do |entry|
          return entry if chain.include?(entry.labeller_name)
        end
        @entries.reverse_each do |entry|
          return entry if entry.type == parent_labeller.type
        end
        nil
      end

      def increment_counter(frame, labeller, parent_hier)
        key = [frame.path, @resolved.instance_name_of(labeller), parent_hier.to_s]
        count = frame.counters[key] + 1
        frame.counters[key] = count
        @totals[key] = count
        count
      end

      def sequence_raw(labeller, position)
        return if labeller.sequence.nil? || labeller.sequence.empty?

        @resolved.sequence_value(labeller.sequence, position)
      end

      def join_hierarchical(parent_hier, raw)
        return parent_hier if parent_hier && raw.nil?
        return raw if parent_hier.nil?

        "#{parent_hier}.#{raw}"
      end

      # MN 112 algorithm step 5: select the first template whose
      # condition evaluates to true; if no condition evaluates to true,
      # select the first template without a condition, or the first
      # template if all have conditions.
      def select_template(templates, total)
        templates.find { |template| template.condition&.evaluate(total) } ||
          templates.find { |template| template.condition.nil? } ||
          templates.first
      end

      def render
        @plan.each do |entry|
          total = @totals.fetch(entry.key, 1)
          labeller = entry.labeller
          local_template = select_template(
            Array(labeller.template), total
          )
          unless local_template
            raise Ladl::ResolutionError,
              "labeller #{entry.labeller_name.inspect} has no label template"
          end
          bindings = base_bindings(entry)
          entry.local = Renderer.render(
            local_template.pattern, bindings.merge(pattern: local_template.pattern)
          )
          globals = Array(labeller.global_template)
          entry.global = if globals.empty?
            entry.local
          else
            global_template = select_template(globals, total)
            Renderer.render(
              global_template.pattern,
              bindings.merge(pattern: global_template.pattern, self: entry.local),
            )
          end
          @result.add(build_label(entry, labeller))
        end
      end

      def base_bindings(entry)
        anchor = entry.parent_frame&.anchor_entry
        {
          n: entry.raw_value,
          pn: entry.parent_hier,
          parent: anchor&.global,
          labels: @labels,
        }
      end

      def build_label(entry, labeller)
        label = Ladl::Label.new(
          value: entry.local,
          global_value: entry.global,
          hierarchical: entry.hierarchical,
          sequence_value: entry.raw_value,
          position: entry.position,
          labeller_id: labeller.id,
          content_element: entry.element.respond_to?(:id) ? entry.element.id : nil,
        )
        label.element = entry.element
        label
      end
    end
  end
end
