# frozen_string_literal: true

module Ladl
  # MN 112 "Label template" — defines how string labels are constructed
  # from labeller values and fixed text.
  #
  # Supported placeholders: `%n` (labeller value), `%pn` (parent labeller
  # value), `%parent` (rendered global label of the parent context
  # element), `%self` (rendered local label of the element itself).
  class LabelTemplate < Lutaml::Model::Serializable
    attribute :pattern, :string
    attribute :direction, :string, default: "ltr"
    attribute :condition, Ladl::LabelContextCondition
    attribute :definition, :string

    hsh do
      map "pattern", to: :pattern
      map "direction", to: :direction
      map "condition", to: :condition
      map "definition", to: :definition
    end

    def conditional?
      !condition.nil?
    end
  end
end
