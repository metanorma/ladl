# frozen_string_literal: true

module Ladl
  # MN 112 "Labeller" — assigns labels to content elements based on their
  # position in the document structure and labeling context, and generates
  # a human-readable label string from a label object.
  #
  # Labellers form the labeller tree: one of the three model trees of
  # MN 112, linked via the `parent` attribute.
  #
  # The `sequence`, `context` and `parent` attributes hold references to
  # profile instances (by instance name) as written in the `.lml`
  # profile; the runtime resolver (Ladl::Runtime::Resolver) wires them to
  # the referenced models. The `template` and `global_template`
  # collections are hydrated into nested Ladl::LabelTemplate objects by
  # the profile loader.
  class Labeller < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :sequence, :string
    attribute :context, :string
    attribute :type, :string
    attribute :parent, :string
    attribute :template, Ladl::LabelTemplate, collection: true
    attribute :global_template, Ladl::LabelTemplate, collection: true
    attribute :definition, :string

    hsh do
      map "id", to: :id
      map "sequence", to: :sequence
      map "context", to: :context
      map "type", to: :type
      map "parent", to: :parent
      map "template", to: :template
      map "global_template", to: :global_template
      map "definition", to: :definition
    end

    # First template of the local template collection; used as the
    # fallback when no template condition matches.
    def first_template
      Array(template).first
    end
  end
end
