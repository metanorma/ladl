# frozen_string_literal: true

module Ladl
  module Runtime
    # The output of a labeling run: the Ladl::Label assigned to each
    # content element, in document order, with lookup by element
    # identity.
    class Result
      include Enumerable

      def initialize
        @labels = []
        @by_element = {}.compare_by_identity
      end

      def add(label)
        @labels << label
        @by_element[label.element] = label if label.element
        label
      end

      def each(&block)
        @labels.each(&block)
      end

      def size
        @labels.size
      end
      alias length size

      def empty?
        @labels.empty?
      end

      # The label for the given content element, or nil.
      def label_for(element)
        @by_element[element]
      end

      # The rendered local label for the given content element, or nil.
      def local_for(element)
        label = @by_element[element]
        label&.value
      end

      # The rendered global label for the given content element, or nil.
      def global_for(element)
        label = @by_element[element]
        label&.global_value
      end

      # Labels keyed by the content element id (elements without an id
      # are omitted).
      def labels_by_element_id
        @labels.each_with_object({}) do |label, hash|
          hash[label.element.id] = label if label.element && label.element.id
        end
      end
    end
  end
end
