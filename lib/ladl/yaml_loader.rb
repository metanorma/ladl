# frozen_string_literal: true

require "set"
require "yaml"

module Ladl
  # Loads LADL profiles written in the YAML realization (MN 112 "Label
  # style realizations"): a single document with `schema: mn112/1` and a
  # sequence of `instances`, each carrying exactly `name`, `type` and
  # `properties`; references are `{ref: Name}` mappings.
  #
  # Validation follows the specification's rejection list: aliases and
  # custom tags are refused, repeated mapping keys are refused, the
  # schema value must be `mn112/1`, instance names must be unique, a
  # `ref` mapping carries no other key and a string value, and every
  # reference resolves to a declared instance or a built-in sequence.
  class YamlLoader
    SCHEMA = "mn112/1"

    class << self
      def load(text)
        new.load(text)
      end
    end

    def load(text)
      document = parse_document(text)
      instances = document["instances"].map { |raw| build_instance(raw) }
      ProfileLoader.new.load_instances(instances,
                                       declared_names: declared_names(instances))
    end

    private

    def parse_document(text)
      document = safe_yaml(text)
      unless document.is_a?(Hash) && document.keys.sort == %w[instances schema]
        raise Ladl::ParseError,
              "a YAML realization is a mapping with exactly the keys " \
              "`schema` and `instances`"
      end
      unless document["schema"] == SCHEMA
        raise Ladl::ParseError,
              "unsupported schema #{document["schema"].inspect}; expected #{SCHEMA.inspect}"
      end
      raise Ladl::ParseError, "`instances` must be a sequence" unless document["instances"].is_a?(Array)

      document
    end

    # Psych with aliases disabled refuses anchors/aliases; custom tags
    # raise on safe_load. Repeated mapping keys are refused by walking
    # the node tree, which Psych's scalar loaders otherwise tolerate.
    def safe_yaml(text)
      tree = Psych.parse(text)
      check_node(tree)
      YAML.safe_load(text, aliases: false)
    rescue Psych::Exception => e
      raise Ladl::ParseError, "invalid YAML realization: #{e.message}"
    end

    def check_node(node)
      case node
      when Psych::Nodes::Alias
        raise Ladl::ParseError, "aliases are not allowed in a realization"
      when Psych::Nodes::Mapping
        keys = node.children.each_slice(2).map(&:first)
        names = keys.map do |key|
          unless key.is_a?(Psych::Nodes::Scalar) && !key.tag
            raise Ladl::ParseError,
                  "mapping keys must be plain scalars"
          end

          key.value
        end
        repeated = names.tally.select { |_, count| count > 1 }
        unless repeated.empty?
          raise Ladl::ParseError,
                "repeated mapping keys: #{repeated.keys.join(", ")}"
        end

        node.children.each { |child| check_node(child) }
      when Psych::Nodes::Sequence, Psych::Nodes::Stream
        node.children.each { |child| check_node(child) }
      when Psych::Nodes::Scalar
        if node.tag
          raise Ladl::ParseError,
                "custom tags are not allowed in a realization"
        end
      when Psych::Nodes::Document
        check_node(node.root)
      end
    end

    def build_instance(raw)
      unless raw.is_a?(Hash) && raw.keys.sort == %w[name properties type]
        raise Ladl::ParseError,
              "each instance mapping has exactly the keys `name`, `type` " \
              "and `properties`"
      end
      name = raw["name"]
      type = raw["type"]
      properties = raw["properties"] || {}
      raise Ladl::ParseError, "instance name must be a non-empty string" unless name.is_a?(String) && !name.empty?
      unless ProfileLoader::CLASS_FOR_BASE.key?(type)
        raise Ladl::ParseError,
              "instance #{name.inspect} realizes unknown model #{type.inspect}"
      end
      unless properties.is_a?(Hash)
        raise Ladl::ParseError,
              "instance #{name.inspect} properties must be a mapping"
      end

      @current_refs = []
      Lml::Instance.new(
        name: name,
        base: type,
        attributes: convert_properties(properties, name),
        references: @current_refs.uniq,
      )
    end

    # `{ref: Name}` mappings become the referenced name, the same
    # representation the LML realization yields for a bare reference,
    # and are recorded for the loader's resolution check.
    def convert_properties(value, instance_name)
      case value
      when Hash
        if value.key?("ref")
          unless value.keys == ["ref"]
            raise Ladl::ParseError,
                  "instance #{instance_name.inspect} has a ref mapping with " \
                  "keys other than `ref`"
          end
          ref = value["ref"]
          unless ref.is_a?(String) && !ref.empty?
            raise Ladl::ParseError,
                  "instance #{instance_name.inspect} has a ref mapping whose " \
                  "value is not a string"
          end
          @current_refs << ref
          ref
        else
          value.transform_values { |v| convert_properties(v, instance_name) }
        end
      when Array
        value.map { |v| convert_properties(v, instance_name) }
      else
        value
      end
    end

    def declared_names(instances)
      (ProfileLoader::BUILTIN_SEQUENCE_NAMES + instances.map(&:name)).to_set
    end
  end
end
