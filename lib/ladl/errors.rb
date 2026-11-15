# frozen_string_literal: true

module Ladl
  # Base error class for all LADL failures.
  class Error < StandardError; end

  # Raised when a `.lml` profile document cannot be parsed.
  class ParseError < Error; end

  # Raised when a profile references an instance that does not exist.
  class ResolutionError < Error; end

  # Raised when a sequence is asked for a position it cannot produce
  # (e.g. a CharacterSequence with expansion rule "none" past its end).
  class SequenceExhaustedError < Error; end
end
