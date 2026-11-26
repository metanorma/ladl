# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "ladl"

# The MN 112-A worked profile instance — spec conformance fixture, not a
# bundled gem profile (flavor profiles live in the flavor gems and the
# taste repo).
LADL_MN112A_PROFILE = File.expand_path("fixtures/iso_iec_label_style.lml", __dir__)

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
end

