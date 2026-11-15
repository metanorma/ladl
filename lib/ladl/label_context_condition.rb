# frozen_string_literal: true

module Ladl
  # MN 112 "Label context condition" — a context condition for a labeller
  # to determine which label template to use, based on the number of
  # similar elements within the same label context.
  #
  # Condition types: `element_count_gt`, `element_count_eq`,
  # `element_count_lt`.
  class LabelContextCondition < Lutaml::Model::Serializable
    attribute :type, :string
    attribute :threshold, :integer

    hsh do
      map "type", to: :type
      map "threshold", to: :threshold
    end

    # Evaluates the condition against the element count of similar
    # elements within the same label context.
    #
    # @param count [Integer] the total number of elements labeled by the
    #   same labeller within the same context instance
    # @return [Boolean]
    # @raise [Ladl::Error] if the condition type is unknown
    def evaluate(count)
      case type
      when "element_count_gt"
        count > threshold
      when "element_count_eq"
        count == threshold
      when "element_count_lt"
        count < threshold
      else
        raise Ladl::Error, "unknown label context condition type: #{type.inspect}"
      end
    end
  end
end
