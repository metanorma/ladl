# frozen_string_literal: true

module Ladl
  # A loaded LADL profile: the LabelStyle model described by the profile
  # document, together with the instance tables of its labellers,
  # contexts, templates, sequences, content elements and labels, keyed by
  # instance name.
  class Profile
    attr_reader :style

    def initialize(style:, labellers: {}, contexts: {}, templates: {},
      sequences: {}, elements: {}, labels: {})
      @style = style
      @labellers = labellers
      @contexts = contexts
      @templates = templates
      @sequences = sequences
      @elements = elements
      @labels = labels
    end

    def labeller(name)
      @labellers[name]
    end

    def labeller_by_id(id)
      @labellers.values.find { |l| l.id == id }
    end

    def context(name)
      @contexts[name]
    end

    def template(name)
      @templates[name]
    end

    def sequence(name)
      @sequences[name]
    end

    def element(name)
      @elements[name]
    end

    def label(name)
      @labels[name]
    end

    def labeller_names
      @labellers.keys
    end

    def context_names
      @contexts.keys
    end

    def template_names
      @templates.keys
    end

    def sequence_names
      @sequences.keys
    end
  end
end
