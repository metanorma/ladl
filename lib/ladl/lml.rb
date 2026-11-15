# frozen_string_literal: true

module Ladl
  # Parsing of LADL profile instances written in the LutaML instance
  # syntax used by MN 112 (`.lml` documents).
  module Lml
    autoload :Parser, "ladl/lml/parser"
    autoload :Document, "ladl/lml/document"
    autoload :Instance, "ladl/lml/instance"
  end
end
