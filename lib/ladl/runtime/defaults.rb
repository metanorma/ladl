# frozen_string_literal: true

module Ladl
  module Runtime
    # The English label vocabulary backing `{key}` tokens in label
    # template patterns — the isodoc i18n key set, so a host document's
    # i18n-<lang>.yaml table slots in directly. Profiles carry the
    # labeling scheme; the vocabulary is language data supplied by the
    # host (Ladl::Runtime::Engine labels:).
    module Defaults
      LABEL_VOCABULARY = {
        "clause" => "Clause",
        "subclause" => "Clause",
        "annex" => "Annex",
        "appendix" => "Appendix",
        "section" => "Section",
        "figure" => "Figure",
        "table" => "Table",
        "formula" => "Formula",
        "inequality" => "Inequality",
        "note" => "NOTE",
        "note_xref" => "NOTE",
        "example" => "EXAMPLE",
        "example_xref" => "EXAMPLE",
        "termexample" => "EXAMPLE",
        "list" => "List",
        "introduction" => "Introduction",
        "norm_annex" => "normative",
        "inform_annex" => "informative",
      }.freeze
    end
  end
end
