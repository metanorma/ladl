# frozen_string_literal: true

module Ladl
  module Lml
    # The parse result of a `.lml` document: the ordered list of its
    # instance declarations.
    class Document
      attr_reader :instances

      def initialize(instances: [])
        @instances = instances
      end

      def add_instance(instance)
        @instances << instance
        instance
      end

      # The first instance with the given name, if any.
      def instance_named(name)
        @instances.find { |i| i.name == name }
      end

      # All instances whose base class name matches `base`.
      def instances_of_base(base)
        @instances.select { |i| i.base == base }
      end
    end
  end
end
