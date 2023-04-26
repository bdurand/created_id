# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

require "active_record"

require "simplecov"
SimpleCov.start do
  add_filter ["/spec/"]
end

Bundler.require(:default, :test)

ActiveRecord::Base.establish_connection("adapter" => "sqlite3", "database" => ":memory:")

require_relative "../lib/created_id"

Dir.glob(File.expand_path("../db/migrate/*.rb", __dir__)).sort.each do |path|
  require(path)
  class_name = File.basename(path).sub(/\.rb\z/, "").split("_", 2).last.camelcase
  class_name.constantize.migrate(:up)
end

ActiveRecord::Base.connection.create_table(:test_model_ones) do |t|
  t.string :name, null: false
  t.datetime :deleted_at
  t.timestamps
end

ActiveRecord::Base.connection.create_table(:test_model_twos) do |t|
  t.string :name, null: false
  t.datetime :deleted_at
  t.timestamps
end

ActiveRecord::Base.connection.create_table(:test_model_threes) do |t|
  t.string :name, null: false
  t.timestamps
end

class TestModelOne < ActiveRecord::Base
  include CreatedId

  default_scope { where(deleted_at: nil) }
end

class TestModelTwo < ActiveRecord::Base
  include CreatedId
end

class TestModelThree < ActiveRecord::Base
  include CreatedId

  base_class
end

class TestModelThreeOne < TestModelThree
end

class TestModelThreeTwo < TestModelThree
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random

  config.after(:each) do
    CreatedId::IdRange.unscoped.delete_all
    TestModelOne.unscoped.delete_all
    TestModelTwo.unscoped.delete_all
    TestModelThree.unscoped.delete_all
  end
end
