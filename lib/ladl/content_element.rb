# frozen_string_literal: true

module Ladl
  # MN 112 "ContentElement" — represents a content element in an
  # information container that can potentially hold a LabelContext object.
  #
  # ContentElements form the content tree: one of the three model trees
  # of MN 112. The `type` attribute is used to match whether a Labeller
  # can label the element.
  class ContentElement < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :type, :string
    attribute :children, Ladl::ContentElement, collection: true
    attribute :definition, :string

    hsh do
      map "id", to: :id
      map "type", to: :type
      map "children", to: :children
      map "definition", to: :definition
    end

    def initialize(*args, **kwargs, &block)
      super
      @children ||= []
    end

    def add_child(child)
      @children << child
      child
    end

    # Depth-first enumeration of the subtree rooted at this element.
    def each(&block)
      return enum_for(:each) unless block

      yield self
      Array(children).each { |c| c.each(&block) }
    end
  end
end
