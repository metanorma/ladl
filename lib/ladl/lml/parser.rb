# frozen_string_literal: true

module Ladl
  module Lml
    # Parser for the subset of the LutaML instance syntax that MN 112
    # profiles are written in:
    #
    #     // comment
    #     instance Name < BaseClass {
    #       attr = "string"
    #       ref = BareReference
    #       count = 3
    #       list = ["a", OtherRef, 3]
    #       condition = { type = "x"  threshold = 1 }
    #       definition { free text
    #         * with bullets }
    #       definition "one line"
    #     }
    #
    # The MN 112 profile syntax uses unquoted instance names and `<`
    # inheritance, which the released LutaML grammar (lutaml-lml) does
    # not accept; this parser covers that draft syntax plus the generic
    # value forms above.
    class Parser
      def self.parse(text)
        new(text).parse
      end

      def initialize(text)
        @tokens = Lexer.new(text).tokens
        @pos = 0
        @pending_isa = nil
      end

      def parse
        document = Document.new
        until (@pos >= @tokens.size || peek.nil? || peek == [:punct, ""])
          document.add_instance(parse_instance)
        end
        document
      end

      private

      def peek
        @tokens[@pos]
      end

      def advance
        token = @tokens[@pos]
        @pos += 1
        token
      end

      def expect(type, value = nil)
        token = advance
        unless token && token[0] == type && (value.nil? || token[1] == value)
          raise ParseError,
            "expected #{value || type} at token #{@pos - 1}, got " \
            "#{token ? token.inspect : "end of input"}"
        end
        token
      end

      def parse_instance
        token = advance
        raise ParseError, "expected an instance declaration, got #{token.inspect}" unless token&.first == :ident

        if token == [:ident, "instance"]
          parse_typed_instance(nil)
        elsif peek && peek.first == :string
          # MN 112 LML realization form: `Type "Name" { ... }`
          parse_typed_instance(token[1])
        else
          # lutaml-lml form: `Type { isa Base; ... }` — the isa body
          # statement supplies the base class.
          expect(:punct, "{")
          @current_refs = []
          attributes = parse_body
          expect(:punct, "}")
          base = @pending_isa
          @pending_isa = nil
          raise Ladl::ParseError,
            "instance #{token[1].inspect} declares no base class (use " \
            "`instance Name < Base`, `Type \"Name\"`, or an `isa` statement)" unless base

          Instance.new(name: token[1], base: base, attributes: attributes,
                       references: @current_refs.uniq)
        end
      end

      # `instance Name [< Base] { ... }` (draft) and, when `type` is
      # given, the MN 112 realization form `Type "Name" { ... }`.
      def parse_typed_instance(type)
        name = parse_name
        base = type
        if base.nil? && peek && peek == [:punct, "<"]
          advance
          base = expect(:ident)[1]
        end
        expect(:punct, "{")
        @current_refs = []
        attributes = parse_body
        expect(:punct, "}")
        # lutaml-lml spells inheritance as a body statement (`isa Base;`)
        # rather than the MN 112 `< Base` form; both are accepted.
        base ||= @pending_isa
        @pending_isa = nil
        Instance.new(name: name, base: base, attributes: attributes,
                     references: @current_refs.uniq)
      end

      def parse_name
        token = peek
        case token&.first
        when :ident
          advance[1]
        when :string
          advance[1]
        else
          raise ParseError, "expected instance name, got #{token.inspect}"
        end
      end

      def parse_body
        attributes = {}
        until (@pos >= @tokens.size || peek == [:punct, "}"])
          parse_body_entry(attributes)
        end
        attributes
      end

      def parse_body_entry(attributes)
        token = advance
        raise ParseError, "unexpected token #{token.inspect} in instance body" unless token

        if token == [:ident, "definition"]
          attributes["definition"] = parse_definition
        elsif token == [:ident, "isa"]
          @pending_isa = parse_name
          advance if peek && peek == [:punct, ";"]
        else
          raise ParseError, "expected attribute name, got #{token.inspect}" unless token[0] == :ident

          attributes[token[1]] = parse_assignment_value
        end
      end

      def parse_assignment_value
        expect(:punct, "=")
        parse_value
      end

      def parse_definition
        token = peek
        case token&.first
        when :raw_block
          advance[1]
        when :string
          advance[1]
        else
          expect(:string)[1]
        end
      end

      def parse_value
        token = peek
        case token&.first
        when :string
          advance[1]
        when :number
          advance[1]
        when :ident
          ident = advance[1]
          case ident
          when "true" then true
          when "false" then false
          when "null" then nil
          when "ref"
            # MN 112 LML realization reference: ref:(Name) — equivalent
            # to the draft syntax's bare identifier, recorded as a
            # reference either way.
            expect(:punct, ":")
            expect(:punct, "(")
            name = parse_name
            expect(:punct, ")")
            @current_refs << name
            name
          else
            # Draft syntax bare reference (e.g. `sequence = Foo`).
            @current_refs << ident
            ident
          end
        when :punct
          if token == [:punct, "["]
            parse_list
          elsif token == [:punct, "{"]
            parse_map
          else
            raise ParseError, "unexpected token #{token.inspect} in value position"
          end
        else
          raise ParseError, "expected value, got #{token.inspect}"
        end
      end

      def parse_list
        expect(:punct, "[")
        items = []
        until (peek == [:punct, "]"])
          items << parse_value
          if peek == [:punct, ","]
            advance
          else
            break
          end
        end
        expect(:punct, "]")
        items
      end

      def parse_map
        expect(:punct, "{")
        attributes = parse_body
        expect(:punct, "}")
        attributes
      end

      # Turns `.lml` source text into a flat token stream. `//` line
      # comments and `/* */` block comments are dropped.
      class Lexer
        def initialize(text)
          @text = text.to_s
          @pos = 0
          @size = @text.length
          @pending = []
        end

        def tokens
          result = []
          until eos?
            result << next_token
          end
          result
        end

        private

        def eos?
          @pos >= @size
        end

        def next_token
          return @pending.shift unless @pending.empty?

          skip_whitespace_and_comments
          return [:punct, ""] if eos?

          ch = @text[@pos]
          case ch
          when "{", "}", "[", "]", "=", ",", "<", ";", ":", "(", ")"
            @pos += 1
            [:punct, ch]
          when '"'
            lex_string
          when /\d/
            lex_number
          when /[A-Za-z_]/
            lex_ident
          when "-"
            lex_number
          else
            raise ParseError,
              "unexpected character #{ch.inspect} at offset #{@pos}"
          end
        end

        def skip_whitespace_and_comments
          until eos?
            ch = @text[@pos]
            if ch =~ /\s/
              @pos += 1
            elsif @text[@pos, 2] == "//"
              skip_until_newline
            elsif @text[@pos, 2] == "/*"
              skip_block_comment
            else
              break
            end
          end
        end

        def skip_until_newline
          while @pos < @size && @text[@pos] != "\n"
            @pos += 1
          end
        end

        def skip_block_comment
          @pos += 2
          until eos? || @text[@pos, 2] == "*/"
            @pos += 1
          end
          @pos += 2 unless eos?
        end

        def lex_string
          @pos += 1
          buffer = +""
          until eos? || @text[@pos] == '"'
            ch = @text[@pos]
            if ch == "\\"
              @pos += 1
              buffer << unescape
            else
              buffer << ch
              @pos += 1
            end
          end
          raise ParseError, "unterminated string at offset #{@pos}" if eos?

          @pos += 1
          [:string, buffer]
        end

        def unescape
          raise ParseError, "unterminated escape at offset #{@pos}" if eos?

          ch = @text[@pos]
          @pos += 1
          { "n" => "\n", "t" => "\t", '"' => '"', "\\" => "\\" }.fetch(ch, ch)
        end

        def lex_number
          start = @pos
          @pos += 1 if @text[@pos] == "-"
          @pos += 1 while !eos? && @text[@pos] =~ /\d/
          [:number, Integer(@text[start...@pos])]
        end

        def lex_ident
          start = @pos
          @pos += 1 while !eos? && @text[@pos] =~ /[A-Za-z0-9_]/
          ident = @text[start...@pos]
          if ident == "definition" && next_nonspace_char == "{"
            @pending << [:raw_block, scan_raw_block]
            [:ident, ident]
          else
            [:ident, ident]
          end
        end

        def next_nonspace_char
          i = @pos
          i += 1 while i < @size && @text[i] =~ /\s/
          @text[i]
        end

        # `definition { ... }` blocks contain free text (bullets, nested
        # braces, slashes, newlines); it is consumed verbatim up to the
        # matching closing brace.
        def scan_raw_block
          i = @pos
          i += 1 while i < @size && @text[i] =~ /\s/
          raise ParseError, "unterminated definition block" if i >= @size || @text[i] != "{"

          i += 1
          depth = 1
          start = i
          while i < @size
            ch = @text[i]
            if ch == "{"
              depth += 1
            elsif ch == "}"
              depth -= 1
              break if depth.zero?
            end
            i += 1
          end
          raise ParseError, "unterminated definition block" if depth.positive?

          @pos = i + 1
          @text[start...i].strip
        end
      end
    end
  end
end
