# frozen_string_literal: true

require "rhoella"

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
    # * `{key}`   — a label vocabulary key, resolved through the labels
    #               dictionary supplied with the profile (the host
    #               document's i18n table, e.g. annex: "Annexe" for
    #               French). Profiles carry the labeling SCHEME; the
    #               vocabulary is language data and comes from the host.
    #               Keys absent from the dictionary fall back to the
    #               English default vocabulary; keys absent from both
    #               are profile errors.
    module Renderer
      PLACEHOLDER = /%pn|%parent|%self|%n|\{([A-Za-z][A-Za-z0-9_]*)\}/.freeze

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
          when /\A\{([A-Za-z][A-Za-z0-9_]*)\}\z/
            label_key(Regexp.last_match(1), bindings)
          end
        end
      end

      # The catalog value is a Fluent message pattern (Metanorma's
      # l10n layer is the rhoella engine): term words are plain
      # messages, designations that need engine values carry
      # `{ $n }`, `{ $pn }`, `{ $parent }` and `{ $self }` placeables
      # bound from the labeller bindings.
      def label_key(key, bindings)
        value = catalog_value(key, bindings)
        Rhoella.format(value, {
          "n" => bindings[:n].to_s,
          "pn" => bindings[:pn].to_s,
          "parent" => bindings[:parent].to_s,
          "self" => bindings[:self].to_s,
        }, message_table(bindings))
      rescue Rhoella::Error => e
        raise Ladl::ResolutionError,
          "template #{bindings[:pattern].inspect} resolves " \
          "{#{key}} to the message #{value.inspect}, which failed " \
          "to render: #{e.message}"
      end

      # The host catalog plus the English default vocabulary form the
      # message catalog that references inside catalog messages resolve
      # against.
      def message_table(bindings)
        table = Defaults::LABEL_VOCABULARY.merge(bindings[:labels] || {})
        table.transform_values(&:to_s)
      end

      def catalog_value(key, bindings)
        labels = bindings[:labels] || {}
        return labels[key].to_s if labels.key?(key)

        Defaults::LABEL_VOCABULARY.fetch(key) do
          raise Ladl::ResolutionError,
            "template #{bindings[:pattern].inspect} uses {#{key}} " \
            "but the key is in neither the labels dictionary nor the " \
            "default vocabulary"
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
