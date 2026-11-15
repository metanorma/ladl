# frozen_string_literal: true

module Ladl
  module Runtime
    # MN 112 "string interpolation" — substitutes variable placeholders
    # in a label template pattern with actual values to construct a
    # rendered label.
    #
    # Supported placeholders:
    #
    # * `%n`      — the labeller value (sequence value at this position)
    # * `%pn`     — the parent labeller value (hierarchical path of the
    #               nearest enclosing parent-labeled element)
    # * `%parent` — the rendered global label of the parent context
    #               element
    # * `%self`   — the rendered local label of the element itself
    module Renderer
      PLACEHOLDER = /%pn|%parent|%self|%n/.freeze

      module_function

      # Renders `pattern` with the given bindings. A `%pn` placeholder in
      # the pattern with no parent value bound is a profile error.
      def render(pattern, bindings)
        pattern.to_s.gsub(PLACEHOLDER) do |placeholder|
          case placeholder
          when "%n"
            text(bindings[:n], placeholder, bindings)
          when "%pn"
            text(bindings[:pn], placeholder, bindings)
          when "%parent"
            text(bindings[:parent], placeholder, bindings)
          when "%self"
            text(bindings[:self], placeholder, bindings)
          end
        end
      end

      def text(value, placeholder, bindings)
        return value.to_s unless value.nil?
        return "" if placeholder == "%parent" || placeholder == "%self"

        raise Ladl::ResolutionError,
          "template #{bindings[:pattern].inspect} uses #{placeholder} " \
          "but the labeller has no parent labeller bound for this element"
      end
    end
  end
end
