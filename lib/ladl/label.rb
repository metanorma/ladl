# frozen_string_literal: true

module Ladl
  # MN 112 "Label" — a machine-readable label assigned to a content
  # element, carrying the rendered local and global label strings plus
  # the intermediate values used to build them.
  class Label < Lutaml::Model::Serializable
    attribute :value, :string
    attribute :global_value, :string
    attribute :hierarchical, :string
    attribute :sequence_value, :string
    attribute :position, :integer
    attribute :labeller_id, :string
    attribute :content_element, :string

    hsh do
      map "value", to: :value
      map "global_value", to: :global_value
      map "hierarchical", to: :hierarchical
      map "sequence_value", to: :sequence_value
      map "position", to: :position
      map "labeller_id", to: :labeller_id
      map "content_element", to: :content_element
    end

    # The runtime element this label is attached to. Not serialized: the
    # element belongs to the host content tree, not to the profile.
    attr_accessor :element
  end
end
