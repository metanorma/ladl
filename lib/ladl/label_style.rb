# frozen_string_literal: true

module Ladl
  # MN 112 "Label style" — a full set of label models sufficient to
  # implement a coherent labeling system for a publisher.
  #
  # The collection attributes hold references to the instances bound to
  # this style, exactly as written in the `.lml` profile: labellers are
  # referenced by id (`"id:clause_labeller"`), the other collections by
  # instance name (`"ClauseLabelTemplate"`).
  class LabelStyle < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :definition, :string
    attribute :labellers, :string, collection: true
    attribute :sequences, :string, collection: true
    attribute :templates, :string, collection: true
    attribute :contexts, :string, collection: true

    hsh do
      map "name", to: :name
      map "definition", to: :definition
      map "labellers", to: :labellers
      map "sequences", to: :sequences
      map "templates", to: :templates
      map "contexts", to: :contexts
    end
  end
end
