# frozen_string_literal: true

# Runs against the INSTALLED ladl gem (see .github/workflows/release.yml):
# boot from the gem's own load paths, load every bundled profile, and
# assert the labeling behaviour that must ship in the released artifact.
# Packaging regressions (gemspec globs dropping the .lml profiles,
# autoload drift) fail the release run here.
require "ladl"

tree = Ladl::ContentElement.new(
  id: "doc", type: "document",
  children: [
    Ladl::ContentElement.new(id: "c1", type: "clause",
      children: [Ladl::ContentElement.new(id: "c1s1", type: "subclause")]),
    Ladl::ContentElement.new(id: "a1", type: "annex",
      children: [Ladl::ContentElement.new(id: "a1c1", type: "clause")]),
  ],
)

failures = []

{
  "iso_iec" => { profile: Ladl.iso_iec_profile,
                 expected: { "c1" => "Clause 1", "c1s1" => "1.1", "a1" => "Annex A", "a1c1" => "A.1" } },
  "ietf" => { profile: Ladl.ietf_profile,
              expected: { "c1" => "1.", "c1s1" => "1.1.", "a1" => "Appendix A.", "a1c1" => "A.1." } },
  "iala_guideline" => { profile: Ladl.iala_guideline_profile,
                        expected: { "c1" => "1", "c1s1" => "1.1", "a1" => "Annex A", "a1c1" => "A.1" } },
  "iala_standard" => { profile: Ladl.iala_standard_profile,
                       expected: { "c1" => "1.", "c1s1" => "1.1.", "a1" => "Annex A", "a1c1" => "A.1." } },
}.each do |name, spec|
  labels = Ladl::Runtime::Engine.new(spec[:profile]).label(tree).labels_by_element_id
  spec[:expected].each do |id, want|
    got = labels[id]&.value
    failures << "#{name}: #{id} expected #{want.inspect}, got #{got.inspect}" unless got == want
  end
end

if failures.empty?
  warn "smoke OK: all bundled profiles label correctly from the installed gem"
else
  warn "smoke FAILED:"
  failures.each { |f| warn "  #{f}" }
  exit 1
end
