# frozen_string_literal: true

require "spec_helper"

# MN 112 "Label style realizations": the LML and YAML realizations are
# equally valid, and a conforming processor derives the same instance
# data from equivalent realizations. The worked pair is the spec's own
# ISO/IEC DIR 2 style instance (MN 112-A).
RSpec.describe "the YAML realization" do
  let(:lml_profile) do
    Ladl::ProfileLoader.load_file(
      File.expand_path("fixtures/iso_iec_label_style_spec_lml.lml", __dir__),
    )
  end

  let(:yaml_profile) do
    Ladl::ProfileLoader.load_file(
      File.expand_path("fixtures/iso_iec_label_style_spec_yaml.yaml", __dir__),
    )
  end

  def instance_data(profile)
    data = { "style" => profile.style.to_hash }
    profile.labeller_names.sort.each do |name|
      data["labeller:#{name}"] = profile.labeller(name).to_hash
    end
    profile.context_names.sort.each do |name|
      data["context:#{name}"] = profile.context(name).to_hash
    end
    profile.template_names.sort.each do |name|
      data["template:#{name}"] = profile.template(name).to_hash
    end
    profile.sequence_names.sort.each do |name|
      data["sequence:#{name}"] = profile.sequence(name).to_hash
    end
    data
  end

  it "derives the same instance data as the LML realization" do
    lml = instance_data(lml_profile)
    yaml = instance_data(yaml_profile)
    expect(yaml).to eq(lml)
    expect(lml.keys.size).to be > 40
  end

  it "loads a YAML profile through Ladl.load_profile by extension" do
    profile = Ladl.load_profile(
      File.expand_path("fixtures/iso_iec_label_style_spec_yaml.yaml", __dir__),
    )
    expect(profile.style.name).to eq(lml_profile.style.name)
    expect(profile.labeller_names).to eq(lml_profile.labeller_names)
  end

  context "validation rejections (MN 112 Validation clause)" do
    let(:header) { "schema: mn112/1\ninstances:\n" }

    def load(text)
      Ladl::ProfileLoader.load_yaml(text)
    end

    it "rejects a wrong schema value" do
      expect { load("#{header.sub("mn112/1", "mn112/2")}- name: A\n  type: LabelStyle\n  properties: {}\n") }
        .to raise_error(Ladl::ParseError, /schema/)
    end

    it "rejects an instance with unknown keys" do
      expect { load("#{header}- name: A\n  type: LabelStyle\n  extra: 1\n  properties: {}\n") }
        .to raise_error(Ladl::ParseError, /exactly the keys/)
    end

    it "rejects an instance realizing an unknown model" do
      expect { load("#{header}- name: A\n  type: NotAModel\n  properties: {}\n") }
        .to raise_error(Ladl::ParseError, /unknown model/)
    end

    it "rejects duplicate instance names" do
      text = header + "- name: A\n  type: LabelStyle\n  properties: {}\n" \
                      "- name: A\n  type: LabelContext\n  properties: {}\n"
      expect { load(text) }.to raise_error(Ladl::ParseError, /duplicate instance name/)
    end

    it "rejects a ref mapping with extra keys or a non-string value" do
      text = "#{header}- name: A\n  type: LabelStyle\n  properties: {x: {ref: B, extra: 1}}\n"
      expect { load(text) }.to raise_error(Ladl::ParseError, /ref mapping/)

      text = "#{header}- name: A\n  type: LabelStyle\n  properties: {x: {ref: 3}}\n"
      expect { load(text) }.to raise_error(Ladl::ParseError, /not a string/)
    end

    it "rejects a reference that resolves to nothing" do
      text = "#{header}- name: A\n  type: LabelStyle\n  properties: {labellers: [{ref: Nowhere}]}\n"
      expect { load(text) }.to raise_error(Ladl::ResolutionError, /Nowhere/)
    end

    it "resolves a reference to a built-in sequence" do
      text = header +
             "- name: A\n  type: Labeller\n  properties: {sequence: {ref: DecimalNumericSequence}}\n" \
             "- name: S\n  type: LabelStyle\n  properties: {}\n"
      expect(load(text).labeller("A").sequence).to eq("DecimalNumericSequence")
    end

    it "rejects YAML aliases" do
      text = header + "- name: A\n  type: LabelStyle\n  properties: &a {}\n" \
                      "- name: B\n  type: LabelContext\n  properties: *a\n"
      expect { load(text) }.to raise_error(Ladl::ParseError, /alias/i)
    end

    it "rejects repeated mapping keys" do
      text = "#{header}- name: A\n  type: LabelStyle\n  properties: {}\n  properties: {}\n"
      expect { load(text) }.to raise_error(Ladl::ParseError, /repeated mapping keys/)
    end
  end
end
