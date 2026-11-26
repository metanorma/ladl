# frozen_string_literal: true

module Ladl
  # MN 112 "ContentElement" — represents a content element in an
  # information container that can potentially hold a LabelContext object.
  #
  # ContentElements form the content tree: one of the three model trees
  # of MN 112. The `type` attribute is used to match whether a Labeller
  # can label the element.
  #
  # Per MN 112, "a ContentElement must be associated with a LabelContext
  # object if it has children to be labeled": the `label_context`
  # attribute names the LabelContext that scopes the element's
  # descendants. The label resolution algorithm navigates the content
  # tree through `parent` to the closest element carrying an
  # association, so the scoping structure is DECLARED by the host as
  # part of the content tree — the engine never infers it.
  class ContentElement < Lutaml::Model::Serializable
    attribute :id, :string
    attribute :type, :string
    attribute :label_context, :string
    attribute :children, Ladl::ContentElement, collection: true
    attribute :definition, :string

    hsh do
      map "id", to: :id
      map "type", to: :type
      map "label_context", to: :label_context
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
