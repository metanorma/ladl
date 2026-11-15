# frozen_string_literal: true

module Ladl
  # MN 112 "NumericSequence" — defines a monotonic sequence of numerical
  # values.
  #
  # The `format` attribute is a runtime extension of this engine: it
  # names the labeling format used to render a position (one of the
  # kinds registered in Ladl::Sequences::Formatters). It carries the
  # MN 112 default labeling sequences (`DecimalNumericSequence`,
  # `RomanUpperNumericSequence`, ...) as profile-loadable data.
  #
  # The `base_sequence` attribute holds the instance name of the base
  # sequence this sequence builds upon; it is resolved at runtime
  # against the registry and the profile-defined sequences.
  class NumericSequence < Lutaml::Model::Serializable
    attribute :char_direction, :string, default: "ltr"
    attribute :initial_value, :integer, default: 1
    attribute :increment, :integer, default: 1
    attribute :cycle_length, :integer
    attribute :base_sequence, :string
    attribute :format, :string
    attribute :definition, :string

    hsh do
      map "char_direction", to: :char_direction
      map "initial_value", to: :initial_value
      map "increment", to: :increment
      map "cycle_length", to: :cycle_length
      map "base_sequence", to: :base_sequence
      map "format", to: :format
      map "definition", to: :definition
    end

    # MN 112 Sequence#value_for_position — provides the value for a given
    # order in the sequence. Delegates the computation to
    # Ladl::Sequences.value_for; `lookup` resolves `base_sequence`
    # references against the runtime registry.
    def value_for_position(position, lookup: nil)
      Ladl::Sequences.value_for(self, position, lookup: lookup)
    end
  end
end
