# frozen_string_literal: true

module Ladl
  # MN 112 "CharacterSequence" — defines a fixed sequence of characters.
  #
  # MN 112 declares both a `char_direction` (on the Sequence base class)
  # and a `direction` (on CharacterSequence); this class carries both and
  # treats `direction` as taking precedence. Expansion rules:,
  # `repeat_label`, `prepend_prefix`, `double_character`, `append_suffix`,
  # `none`.
  class CharacterSequence < Lutaml::Model::Serializable
    attribute :char_direction, :string, default: "ltr"
    attribute :characters, :string, collection: true
    attribute :expansion_rule, :string
    attribute :expansion_prefix, :string, collection: true
    attribute :direction, :string, default: "ltr"
    attribute :definition, :string

    hsh do
      map "char_direction", to: :char_direction
      map "characters", to: :characters
      map "expansion_rule", to: :expansion_rule
      map "expansion_prefix", to: :expansion_prefix
      map "direction", to: :direction
      map "definition", to: :definition
    end

    # MN 112 Sequence#value_for_position — provides the value for a given
    # order in the sequence. Delegates the computation to
    # Ladl::Sequences.value_for.
    def value_for_position(position, lookup: nil)
      Ladl::Sequences.value_for(self, position, lookup: lookup)
    end
  end
end
