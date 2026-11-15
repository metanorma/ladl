# frozen_string_literal: true

module Ladl
  module Runtime
    # Wires a loaded Ladl::Profile into the indexes the engine needs:
    # labellers by context instance and element type, context instances
    # by name attribute and parent relation, sequence resolution, and
    # the labeller-tree descendant index used for `%pn` resolution.
    class Resolver
      attr_reader :profile

      def initialize(profile)
        @profile = profile
        validate_style_references
        @labeller_names = {}
        @profile.labeller_names.each do |name|
          @labeller_names[@profile.labeller(name)] = name
        end
        @labellers_by_context = build_labeller_index
        @descendants = build_descendants
        @context_names = {}
        @profile.context_names.each do |name|
          context = @profile.context(name)
          @context_names[name] = context.name if context.name
        end
      end

      # The labeller bound to `context_instance_name` (a context
      # instance name, e.g. "ClauseContext") that labels elements of
      # `type`, or nil.
      def labeller_for_context(context_instance_name, type)
        @labellers_by_context.dig(context_instance_name, type)
      end

      # The `name` attribute of the context instance with the given
      # instance name (e.g. "ClauseContext" -> "clause").
      def context_name(instance_name)
        @context_names[instance_name]
      end

      # Instance names of contexts whose `parent` is the given context
      # instance name.
      def contexts_with_parent(instance_name)
        @profile.context_names.select do |name|
          @profile.context(name).parent == instance_name
        end
      end

      # Instance names of contexts whose `name` attribute equals the
      # given element type (e.g. "clause" -> ["ClauseContext"]).
      def contexts_named(type)
        @profile.context_names.select do |name|
          @context_names[name] == type
        end
      end

      # Sequence value for the given sequence reference (instance name)
      # at the given 1-based position; nil when the reference is blank.
      def sequence_value(sequence_name, position)
        return if sequence_name.nil? || sequence_name.empty?

        sequence = @profile.sequence(sequence_name) || Sequences::Registry.lookup(sequence_name)
        unless sequence
          raise Ladl::ResolutionError,
            "undefined sequence: #{sequence_name.inspect}"
        end
        Sequences.value_for(sequence, position, lookup: method(:lookup_sequence))
      end

      # True when `labeller_name` is a strict descendant of
      # `ancestor_name` in the labeller tree.
      def descendant_labeller?(ancestor_name, labeller_name)
        @descendants[ancestor_name].include?(labeller_name)
      end

      # The self-inclusive ancestor chain of the given labeller instance
      # name: the labeller itself followed by its parent, grandparent,
      # ... in the labeller tree.
      def ancestor_chain(labeller_name)
        chain = [labeller_name]
        seen = { labeller_name => true }
        current = labeller_name
        while (parent = @profile.labeller(current)&.parent)
          break if seen.key?(parent)

          chain << parent
          seen[parent] = true
          current = parent
        end
        chain
      end

      # The instance name of a labeller model within the profile.
      def instance_name_of(labeller)
        @labeller_names[labeller]
      end

      # The parent labeller instance name of the given labeller, or nil.
      def parent_labeller_name(labeller)
        labeller.parent
      end

      def lookup_sequence(name)
        @profile.sequence(name) || Sequences::Registry.lookup(name)
      end

      private

      def validate_style_references
        missing = []
        Array(@profile.style.labellers).each do |ref|
          id = ref.start_with?("id:") ? ref[3..] : ref
          missing << ref unless @profile.labeller_by_id(id) || @profile.labeller(ref)
        end
        Array(@profile.style.contexts).each do |ref|
          missing << ref unless @profile.context(ref)
        end
        Array(@profile.style.templates).each do |ref|
          missing << ref unless @profile.template(ref)
        end
        Array(@profile.style.sequences).each do |ref|
          next if @profile.sequence(ref) || Sequences::Registry.lookup(ref)

          missing << ref
        end
        unless missing.empty?
          raise Ladl::ResolutionError,
            "label style #{@profile.style.name.inspect} references " \
            "undefined instances: #{missing.join(", ")}"
        end
      end

      def build_labeller_index
        index = Hash.new { |h, k| h[k] = {} }
        @profile.labeller_names.each do |name|
          labeller = @profile.labeller(name)
          context = labeller.context
          unless context
            raise Ladl::ResolutionError,
              "labeller #{name.inspect} declares no context"
          end
          unless @profile.context(context)
            raise Ladl::ResolutionError,
              "labeller #{name.inspect} references undefined context " \
              "#{context.inspect}"
          end
          index[context][labeller.type] = labeller
        end
        index
      end

      def build_descendants
        children = Hash.new { |h, k| h[k] = [] }
        @profile.labeller_names.each do |name|
          labeller = @profile.labeller(name)
          children[labeller.parent] << name if labeller.parent
        end
        descendants = Hash.new { |h, k| h[k] = [] }
        @profile.labeller_names.each do |name|
          collect_descendants(name, children, descendants[name])
        end
        descendants
      end

      def collect_descendants(name, children, into)
        children[name].each do |child|
          into << child
          collect_descendants(child, children, into)
        end
        into.uniq!
        into
      end
    end
  end
end
