# frozen_string_literal: true

module Ladl
  module Lml
    # A parsed `instance` declaration from a `.lml` document: its name,
    # its base class (after `<`), and its attribute map. Attribute values
    # are plain Ruby data: String, Integer, true/false, nil, Array, or a
    # nested Hash (from `{ ... }` blocks). `references` lists the value
    # positions that were references (bare identifiers or `ref:(Name)`
    # forms) so the loader can verify they resolve.
    class Instance
      attr_reader :name, :base, :attributes, :references

      def initialize(name:, base: nil, attributes: {}, references: [])
        @name = name
        @base = base
        @attributes = attributes
        @references = references
      end
    end
  end
end
