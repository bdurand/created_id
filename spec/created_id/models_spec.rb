# frozen_string_literal: true

require "spec_helper"

RSpec.describe "CreatedId.models" do
  around do |example|
    registered = CreatedId.instance_variable_get(:@registered_models)
    included = CreatedId.instance_variable_get(:@included_models)
    begin
      example.run
    ensure
      CreatedId.instance_variable_set(:@registered_models, registered)
      CreatedId.instance_variable_set(:@included_models, included)
    end
  end

  it "returns all loaded models that include CreatedId sorted by name" do
    expect(CreatedId.models).to eq([TestModelOne, TestModelThree, TestModelTwo])
  end

  it "includes registered models that have not been loaded" do
    # The class is anonymous when CreatedId is included so it is not tracked until it is registered.
    stub_const("LazyCreatedIdModel", Class.new(ActiveRecord::Base) { include CreatedId })
    expect(CreatedId.models).to_not include(LazyCreatedIdModel)

    CreatedId.register_models("LazyCreatedIdModel")
    expect(CreatedId.models).to eq([LazyCreatedIdModel, TestModelOne, TestModelThree, TestModelTwo])
  end

  it "accepts class names as strings, symbols, or classes" do
    CreatedId.register_models("TestModelOne", :TestModelTwo, [TestModelThree])
    expect(CreatedId.registered_models).to eq(["TestModelOne", "TestModelTwo", "TestModelThree"])
  end

  it "does not duplicate registered models" do
    CreatedId.register_models("TestModelOne")
    CreatedId.register_models("TestModelOne", "TestModelTwo")
    expect(CreatedId.registered_models).to eq(["TestModelOne", "TestModelTwo"])
    expect(CreatedId.models).to eq([TestModelOne, TestModelThree, TestModelTwo])
  end

  it "only returns the base class for single table inheritance models" do
    CreatedId.register_models("TestModelThreeOne", "TestModelThreeTwo")
    expect(CreatedId.models).to eq([TestModelOne, TestModelThree, TestModelTwo])
  end

  it "returns the most recently loaded definition of a class" do
    original = TestModelTwo
    stub_const("TestModelTwo", Class.new(ActiveRecord::Base) { include CreatedId })
    expect(CreatedId.models).to include(TestModelTwo)
    expect(CreatedId.models).to_not include(original)
  end

  it "does not return abstract classes" do
    stub_const("AbstractCreatedIdModel", Class.new(ActiveRecord::Base) {
      self.abstract_class = true
      include CreatedId
    })
    CreatedId.register_models("AbstractCreatedIdModel")
    expect(CreatedId.models).to eq([TestModelOne, TestModelThree, TestModelTwo])
  end

  it "raises an error if a registered model does not include CreatedId" do
    stub_const("NonCreatedIdModel", Class.new(ActiveRecord::Base))
    CreatedId.register_models("NonCreatedIdModel")
    expect { CreatedId.models }.to raise_error(ArgumentError, /NonCreatedIdModel/)
  end

  it "raises an error if a registered model does not exist" do
    CreatedId.register_models("MissingCreatedIdModel")
    expect { CreatedId.models }.to raise_error(NameError)
  end
end
