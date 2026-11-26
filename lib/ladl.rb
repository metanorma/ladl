# frozen_string_literal: true

require "lutaml/model"

# LADL — the Label Auto-assignment Definition Language.
#
# A declarative modeling language for defining automatic label assignment
# across technical documentation and publishing systems, as specified in
# MN 112.
#
# The gem is organized around the three model trees of MN 112:
#
# * The content tree (Ladl::ContentElement) — the elements being labeled.
# * The context tree (Ladl::LabelContext) — the label contexts that scope
#   labeller counters.
# * The labeller tree (Ladl::Labeller) — hierarchical labellers that assign
#   labels to content elements.
#
# A profile (a LutaML `.lml` instance document) is loaded with
# Ladl::ProfileLoader into a Ladl::Profile, resolved into a
# Ladl::Runtime::Resolver, and evaluated against a content tree by the
# Ladl::Runtime::Engine.
module Ladl
  autoload :VERSION, "ladl/version"
  autoload :Error, "ladl/errors"
  autoload :ParseError, "ladl/errors"
  autoload :ResolutionError, "ladl/errors"
  autoload :SequenceExhaustedError, "ladl/errors"

  # Core models (MN 112 "Core models")
  autoload :LabelStyle, "ladl/label_style"
  autoload :LabelContext, "ladl/label_context"
  autoload :Labeller, "ladl/labeller"
  autoload :LabelTemplate, "ladl/label_template"
  autoload :LabelContextCondition, "ladl/label_context_condition"
  autoload :NumericSequence, "ladl/numeric_sequence"
  autoload :CharacterSequence, "ladl/character_sequence"
  autoload :ContentElement, "ladl/content_element"
  autoload :Label, "ladl/label"

  # Profile loading
  autoload :Lml, "ladl/lml"
  autoload :Profile, "ladl/profile"
  autoload :ProfileLoader, "ladl/profile_loader"

  # Default sequences provided by the runtime (MN 112 "NumericSequence")
  autoload :Sequences, "ladl/sequences"

  # Labeling engine
  autoload :Runtime, "ladl/runtime"

  # Input adapters (thin wrappers over host document models)
  autoload :Adapters, "ladl/adapters"

  module_function

  # Loads a LADL profile from a `.lml` file path. The engine ships NO
  # bundled profiles: per the release plan, each flavor profile lives in
  # its flavor gem and each taste profile in metanorma-taste (one LADL
  # profile extraction per flavor gem / per taste).
  def load_profile(path)
    ProfileLoader.load_file(path)
  end
end
