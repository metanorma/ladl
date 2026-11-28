# frozen_string_literal: true

module Ladl
  # Loads LADL profiles written in the LutaML `.lml` instance syntax
  # (MN 112 worked profile format) into typed Ladl profile models.
  #
  # Every instance is hydrated through the lutaml-model framework
  # (Model.from_hash) against the hash mappings declared on the model
  # classes; this class only groups instances by their base class and
  # substitutes labeller template references with the referenced
  # template instances.
  class ProfileLoader
    CLASS_FOR_BASE = {
      "LabelStyle" => -> { Ladl::LabelStyle },
      "LabelContext" => -> { Ladl::LabelContext },
      "Labeller" => -> { Ladl::Labeller },
      "LabelTemplate" => -> { Ladl::LabelTemplate },
      "LabelTemplateVariant" => -> { Ladl::LabelTemplateVariant },
      "NumericSequence" => -> { Ladl::NumericSequence },
      "CharacterSequence" => -> { Ladl::CharacterSequence },
      "ContentElement" => -> { Ladl::ContentElement },
      "Label" => -> { Ladl::Label },
    }.freeze

    BUILTIN_SEQUENCE_NAMES = Sequences::Registry.defaults.keys.freeze

    class << self
      def load_lml(text)
        new.load_lml(text)
      end

      def load_yaml(text)
        new.load_yaml(text)
      end

      def load_file(path)
        new.load_file(path)
      end
    end

    def load_file(path)
      case File.extname(path).downcase
      when ".yaml", ".yml"
        load_yaml(File.read(path, encoding: "UTF-8"))
      else
        load_lml(File.read(path, encoding: "UTF-8"))
      end
    end

    def load_lml(text)
      document = Lml::Parser.parse(text)
      instances = document.instances
      check_duplicate_names(instances)
      build_profile(instances)
    end

    def load_yaml(text)
      require_relative "yaml_loader"
      YamlLoader.load(text)
    end

    # Shared pipeline for the realizations: index the parsed instances,
    # verify references resolve, and build the Profile.
    def load_instances(instances, declared_names:)
      check_duplicate_names(instances)
      check_references(instances, declared_names)
      build_profile(instances)
    end

    private

    def check_duplicate_names(instances)
      names = instances.map(&:name)
      repeated = names.tally.select { |_, count| count > 1 }
      raise Ladl::ParseError,
        "duplicate instance name in profile: #{repeated.keys.join(", ")}" unless repeated.empty?
    end

    # MN 112 "Label style realizations": a reference resolves to a
    # declared instance or a built-in sequence. Refs are recorded at
    # parse/conversion time — a bare LML identifier and a YAML
    # `{ref:}` mapping are references; quoted strings never are.
    def check_references(instances, declared_names)
      instances.each do |instance|
        instance.references.each do |ref|
          next if declared_names.include?(ref)

          raise Ladl::ResolutionError,
            "instance #{instance.name.inspect} references undefined " \
            "instance #{ref.inspect}"
        end
      end
    end

    def build_profile(instances)
      @index = {}
      instances.each { |instance| @index[instance.name] = instance }
      built = {}
      @index.each do |name, instance|
        built[name] = hydrate(name, instance)
      end
      style = built.values.find { |m| m.is_a?(Ladl::LabelStyle) }
      raise Ladl::ParseError, "profile defines no LabelStyle instance" unless style

      Profile.new(
        style: style,
        labellers: select_models(built, Ladl::Labeller),
        contexts: select_models(built, Ladl::LabelContext),
        templates: select_models(built, Ladl::LabelTemplate),
        sequences: select_models(built, Ladl::NumericSequence, Ladl::CharacterSequence),
        elements: select_models(built, Ladl::ContentElement),
        labels: select_models(built, Ladl::Label),
      )
    end

    def select_models(built, *types)
      built.select { |_, model| types.any? { |t| model.is_a?(t) } }
    end

    def hydrate(name, instance)
      klass = class_for_base(name, instance)
      attrs = prepared_attributes(name, instance)
      klass.from_hash(attrs)
    end

    def class_for_base(name, instance)
      unless instance.base
        raise Ladl::ParseError,
          "instance #{name.inspect} declares no base class"
      end
      unless (klass = CLASS_FOR_BASE[instance.base]&.call)
        raise Ladl::ParseError,
          "instance #{name.inspect} extends unknown base class " \
          "#{instance.base.inspect}"
      end
      klass
    end

    # Labeller template references are substituted with the referenced
    # template instances' attribute hashes so that from_hash hydrates
    # nested Ladl::LabelTemplate objects (MN 112 labeller/template
    # references are by instance name).
    def prepared_attributes(_name, instance)
      attrs = instance.attributes.dup
      substitute_template_ref(attrs, "template")
      substitute_template_ref(attrs, "global_template")
      substitute_variant_ref(attrs, "variants")
      attrs
    end

    def substitute_template_ref(attrs, key)
      return unless attrs.key?(key)

      value = attrs[key]
      attrs[key] = resolve_template_list(value)
    end

    # Label template variant references are substituted with the
    # referenced variant instances' attribute hashes so that from_hash
    # hydrates nested LabelTemplateVariant objects (MN 112 language
    # variants are declared as instances and referenced by name).
    def substitute_variant_ref(attrs, key)
      return unless attrs.key?(key)

      refs = Array(attrs[key])
      attrs[key] = refs.map do |ref|
        case ref
        when String
          variant_instance = @index[ref]
          unless variant_instance
            raise Ladl::ResolutionError,
              "template references undefined variant instance #{ref.inspect}"
          end
          variant_instance.attributes.dup
        when Hash
          ref.dup
        else
          raise Ladl::ParseError,
            "invalid variant reference: #{ref.inspect}"
        end
      end
    end

    def resolve_template_list(value)
      refs = value.is_a?(Array) ? value : [value]
      refs.map do |ref|
        case ref
        when String
          template_instance = @index[ref]
          unless template_instance
            raise Ladl::ResolutionError,
              "labeller references undefined template instance #{ref.inspect}"
          end
          resolve_template_instance(template_instance)
        when Hash
          ref.dup
        else
          raise Ladl::ParseError,
            "invalid template reference: #{ref.inspect}"
        end
      end
    end

    def resolve_template_instance(template_instance)
      attrs = template_instance.attributes.dup
      substitute_variant_ref(attrs, "variants")
      attrs
    end
  end
end
