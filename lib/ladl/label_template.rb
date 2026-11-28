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
    attribute :variants, Ladl::LabelTemplateVariant, collection: true
    attribute :definition, :string

    hsh do
      map "pattern", to: :pattern
      map "direction", to: :direction
      map "condition", to: :condition
      map "variants", to: :variants
      map "definition", to: :definition
    end

    def conditional?
      !condition.nil?
    end

    # The pattern for a host language: the variant declared for that
    # language when one exists, the base pattern otherwise (including
    # when the engine carries no language).
    def pattern_for(lang)
      return pattern unless lang

      variant = Array(variants).find { |v| v.lang == lang.to_s }
      variant ? variant.pattern : pattern
    end
  end
end
