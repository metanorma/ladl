# frozen_string_literal: true

module Ladl
  # MN 112 "Label template language variant" — a language-specific
  # pattern that replaces the base pattern of its label template when
  # the engine renders for that language.
  #
  # Designations whose structure varies by language — the French notes
  # to terminological entries read "Note 1 à l'article 3.1", embedding
  # the parent reference where English reads "Note 1 to entry" — are
  # declared as variants on the one template, not as one profile per
  # language: the numbering scheme is language-invariant (ISO/IEC
  # Directives, Part 2, 8.1 requires structurally identical language
  # versions), only the designation patterns differ.
  class LabelTemplateVariant < Lutaml::Model::Serializable
    attribute :lang, :string
    attribute :pattern, :string
    attribute :definition, :string

    hsh do
      map "lang", to: :lang
      map "pattern", to: :pattern
      map "definition", to: :definition
    end
  end
end
