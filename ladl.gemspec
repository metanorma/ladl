# frozen_string_literal: true

require_relative "lib/ladl/version"

Gem::Specification.new do |spec|
  spec.name = "ladl"
  spec.version = Ladl::VERSION
  spec.authors = ["Ronald Tse"]
  spec.email = ["ronald.tse@ribose.com"]

  spec.summary = "Label Auto-assignment Definition Language (LADL) engine"
  spec.description = <<~DESCRIPTION
    Declarative auto-numbering and labeling engine implementing MN 112
    (Label Auto-assignment Definition Language, LADL). Parses labeling
    style profiles written in the LutaML instance syntax and evaluates
    labels, numbers and sequences against a content tree over the three
    LADL model trees: the content tree, the context tree and the
    labeller tree.
  DESCRIPTION
  spec.homepage = "https://github.com/metanorma/ladl"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.lml"] + Dir["lib/**/*.rb"] +
    Dir["LICENSE.txt"] + Dir["README.adoc"]
  spec.require_paths = ["lib"]

  spec.add_dependency "lutaml-model", "~> 0.8"

  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "rspec", "~> 3"
end
