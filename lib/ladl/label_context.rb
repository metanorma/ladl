# frozen_string_literal: true

module Ladl
  # MN 112 "Label context" — defines the scope of labeling (and a label
  # hierarchy) within an information container.
  #
  # Instances of LabelContext form the context tree: one of the three
  # model trees of MN 112, linked via the `parent` attribute.
  class LabelContext < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :parent, :string
    attribute :element, :string
    attribute :labellers, :string, collection: true
    attribute :definition, :string

    hsh do
      map "name", to: :name
      map "parent", to: :parent
      map "element", to: :element
      map "labellers", to: :labellers
      map "definition", to: :definition
    end
  end
end
