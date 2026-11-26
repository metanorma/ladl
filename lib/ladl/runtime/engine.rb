# frozen_string_literal: true

module Ladl
  module Runtime
    # The LADL labeling evaluator (MN 112 "Algorithm to resolve the
    # label for a content element").
    #
    # The evaluator is a thin kernel over the three model trees:
    #
    # * The CONTENT TREE arrives from the host: ContentElements carrying
    #   `type`, and — for elements with children to be labeled — the
    #   DECLARED `label_context` association. The scoping structure is
    #   the host's declaration; the evaluator never infers it.
    # * The CONTEXT TREE and LABELLER TREE come from the profile.
    #
    # Resolution, per MN 112:
    #
    # 1. From the ContentElement, find its applicable LabelContext: the
    #    element's own association, else the closest one navigated
    #    through `parent`.
    # 2. From that context, find the Labeller applicable to the
    #    element's type.
    # 3. The Labeller generates the label: the first LabelTemplate whose
    #    condition holds (the element count of similar elements in the
    #    same context), the Sequence value at the element's position in
    #    that context, and the parent labeller's value where the
    #    template requires it.
    #
    # Counters are scoped by the context instance — the element carrying
    # the association — so like-labeled elements under different
    # carriers number independently.
    class Engine
      # A labeled element planned during the walk.
      Entry = Struct.new(:element, :type, :labeller, :labeller_name,
        :context_name, :carrier_object_id, :carrier_entry, :position,
        :raw_value, :parent_hier, :parent_entry, :hierarchical, :local,
        :global, keyword_init: true)

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
        @plan = []
        @totals = Hash.new(0)
        @result = Result.new
      end

      # Labels the content tree rooted at `root` and returns the
      # Ladl::Runtime::Result.
      def label(root)
        @result = Result.new
        @plan = []
        @totals = Hash.new(0)
        walk(root, [])
        render
        @result
      end
      alias label_document label

      private

      # MN 112 step 1 has two independent resolutions:
      #
      # * The element's own LABEL: the first context in the association
      #   chain (self, then ancestors nearest-first) whose labeller
      #   binds the element's type. An association whose context has no
      #   labeller for the type is skipped — it scopes but does not
      #   label (a sub-clause context scopes its notes yet carries no
      #   sub-clause labeller).
      # * The element's SCOPE CARRIER for its descendants and its
      #   `%parent` value: the nearest association (self, then
      #   ancestors), whose context may bind nothing itself.
      def walk(element, ancestors)
        labeller, label_context_name, label_carrier =
          resolve_own_label(element, ancestors)
        association = nearest_association(element, ancestors)
        # The frame carries only the element's OWN declared association
        # — inherited scopes do not masquerade as associations, so the
        # carrier of `%parent` stays the element that declared it.
        frame = { element: element, declared: element.label_context,
          entry: nil }
        frame[:entry] = if labeller
          plan_element(element, labeller, label_context_name,
            label_carrier, association, ancestors)
        end
        ancestors.push(frame)
        children_of(element).each { |child| walk(child, ancestors) }
        ancestors.pop
      end

      # The element's own label: the first context in the association
      # chain (self, then ancestors nearest-first) whose labeller binds
      # the element's type. Associations whose context binds no labeller
      # for the type are skipped — they scope descendants but do not
      # label this element (a sub-clause context scopes its notes yet
      # carries no sub-clause labeller).
      # Returns [labeller, context name, the frame whose context
      # supplied the label].
      def resolve_own_label(element, ancestors)
        if element.label_context
          labeller = resolve_labeller(element.label_context, element.type.to_s)
          return [labeller, element.label_context,
            { element: element, context_name: element.label_context,
              entry: nil }] if labeller
        end
        ancestors.reverse_each do |frame|
          next unless frame[:declared]

          labeller = resolve_labeller(frame[:declared], element.type.to_s)
          return [labeller, frame[:declared], frame] if labeller
        end
        [nil, nil, nil]
      end

      # The nearest association frame (self, then ancestors nearest
      # first).
      def nearest_association(element, ancestors)
        if element.label_context
          return { element: element, context_name: element.label_context,
            entry: nil }
        end

        ancestors.reverse_each do |frame|
          return frame if frame[:declared]
        end
        nil
      end

      # MN 112 step 2: the Labeller applicable to the element's type in
      # the resolved context.
      def resolve_labeller(context_name, type)
        @resolved.labeller_for_context(context_name, type)
      end

      def children_of(element)
        Array(element.children)
      end

      def plan_element(element, labeller, context_name, label_carrier,
        scope_association, ancestors)
        parent = find_parent_entry(labeller, ancestors)
        parent_hier = parent&.hierarchical
        position = increment_counter(label_carrier, labeller, parent_hier)
        raw = sequence_raw(labeller, position)
        entry = Entry.new(
          element: element,
          type: element.type.to_s,
          labeller: labeller,
          labeller_name: @resolved.instance_name_of(labeller),
          context_name: context_name,
          carrier_object_id: label_carrier[:element].object_id,
          carrier_entry: scope_association && scope_association[:entry],
          position: position,
          raw_value: raw,
          parent_hier: parent_hier,
          parent_entry: parent,
          hierarchical: join_hierarchical(parent_hier, raw),
        )
        # A self-associated element is its own scope instance: `%parent`
        # resolves to its own label.
        if scope_association && scope_association[:element].equal?(element)
          scope_association[:entry] = entry
          entry.carrier_entry = entry
        end
        @plan << entry
        entry
      end

      # The nearest ancestor element labeled by this labeller's parent
      # labeller: it supplies the `%pn` value (its hierarchical label)
      # and anchors the hierarchical counter scope. Falls back to the
      # nearest ancestor entry of the parent labeller's element type —
      # an enclosing figure labeled by the annex figure labeller still
      # supplies a subfigure's `%pn` across flavor bindings.
      def find_parent_entry(labeller, ancestors)
        parent_name = labeller.parent
        return nil if parent_name.nil? || parent_name.empty?

        parent_labeller = @resolved.profile.labeller(parent_name)
        unless parent_labeller
          raise Ladl::ResolutionError,
            "labeller #{@resolved.instance_name_of(labeller).inspect} " \
            "references undefined parent labeller #{parent_name.inspect}"
        end
        chain = @resolved.ancestor_chain(@resolved.instance_name_of(labeller))
        ancestors.reverse_each do |frame|
          entry = frame[:entry]
          return entry if entry && chain.include?(entry.labeller_name)
        end
        ancestors.reverse_each do |frame|
          entry = frame[:entry]
          return entry if entry && entry.type == parent_labeller.type
        end
        nil
      end

      # The position of the element in its context: the count of like-
      # labeled elements under the same carrier, restarted per
      # hierarchical scope.
      def increment_counter(carrier, labeller, parent_hier)
        key = counter_key(carrier[:element].object_id,
          @resolved.instance_name_of(labeller), parent_hier)
        @totals[key] += 1
        @totals[key]
      end

      def counter_key(carrier_id, labeller_name, parent_hier)
        [carrier_id, labeller_name, parent_hier.to_s]
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

      # MN 112 step 3: template selection (the first condition that
      # holds, else the first unconditional, else the first), then
      # rendering with the sequence value, the parent-labeller value and
      # the carrier element's label.
      def render
        @plan.each do |entry|
          labeller = entry.labeller
          total = @totals.fetch(counter_key(entry.carrier_object_id,
            entry.labeller_name, entry.parent_hier), 1)
          local_template = select_template(Array(labeller.template), total)
          raise Ladl::ResolutionError,
            "labeller #{entry.labeller_name.inspect} has no label template" unless local_template

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

      def select_template(templates, total)
        templates.find { |template| template.condition&.evaluate(total) } ||
          templates.find { |template| template.condition.nil? } ||
          templates.first
      end

      def base_bindings(entry)
        {
          n: entry.raw_value,
          pn: entry.parent_hier,
          parent: entry.carrier_entry&.global,
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
          content_element: entry.element.id,
        )
        label.element = entry.element
        label
      end
    end
  end
end
