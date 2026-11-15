# frozen_string_literal: true

module Ladl
  module Lml
    # A parsed `instance` declaration from a `.lml` document: its name,
    # its base class (after `<`), and its attribute map. Attribute values
    # are plain Ruby data: String, Integer, true/false, nil, Array, or a
    # nested Hash (from `{ ... }` blocks).
    class Instance
      attr_reader :name, :base, :attributes

      def initialize(name:, base: nil, attributes: {})
        @name = name
        @base = base
        @attributes = attributes
      end
    end
  end
end
