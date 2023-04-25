# frozen_string_literal: true

require_relative "spec_helper"

describe CreatedId do
  it "has a version number" do
    expect(CreatedId::VERSION).not_to be nil
  end

  describe "store_created_id_for" do
    it "can calculates and stores the min id for records created on a date" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 1, 1, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.utc(2023, 1, 2, 0, 0))
      four = TestModelOne.create!(name: "Four", created_at: Time.utc(2023, 1, 2, 0, 1))

      TestModelOne.store_created_id_for(Date.new(2023, 1, 1))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 2))

      expect(CreatedId::Model.find_by(class_name: "TestModelOne", created_on: Date.new(2023, 1, 1)).min_id).to eq(one.id)
      expect(CreatedId::Model.find_by(class_name: "TestModelOne", created_on: Date.new(2023, 1, 2)).min_id).to eq(three.id)
    end

    it "does not store a min id if there are no records created on a date" do
      TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1, 0, 1))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 2))
      expect(CreatedId::Model.find_by(class_name: "TestModelOne", created_on: Date.new(2023, 1, 2))).to be_nil
    end

    it "ignores the default scope when setting the min id" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1, 0, 1), deleted_at: Time.new(2023, 1, 1, 0, 2))
      two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 1, 1, 0, 2))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 1))
      expect(CreatedId::Model.find_by(class_name: "TestModelOne", created_on: Date.new(2023, 1, 1)).min_id).to eq(one.id)
    end
  end

  describe "created_after" do
    it "finds records created after a time" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 1, 1, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.utc(2023, 1, 2, 0, 0))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 1))

      query = TestModelOne.created_after(Time.utc(2023, 1, 1, 0, 2))
      expect(query.first).to eq(two)
    end

    it "optimizes searches for records created after a time" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1, 0, 1))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 1))
      query = TestModelOne.created_after(Time.utc(2023, 1, 1, 0, 2))
      expect(query.to_sql).to include("\"id\" >= #{one.id}")
    end

    it "finds records even if the min id is not stored" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 1, 1, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.utc(2023, 1, 2, 0, 0))

      query = TestModelOne.created_after(Time.utc(2023, 1, 1, 0, 2))
      expect(query.first).to eq(two)
    end
  end

  describe "created_before" do
    it "finds records created before a time" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 1, 1, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.utc(2023, 1, 2, 0, 0))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 2))

      query = TestModelOne.created_before(Time.utc(2023, 1, 1, 0, 2))
      expect(query.last).to eq(one)

      query = TestModelOne.created_before(Date.new(2023, 1, 2))
      expect(query.last).to eq(two)
    end

    it "optimizes searches for records created before a time" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 2, 0, 1))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 2))
      query = TestModelOne.created_before(Time.utc(2023, 1, 1, 0, 2))
      expect(query.to_sql).to include("\"id\" < #{one.id}")
    end

    it "finds records even if the min id is not stored" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 1, 1, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.utc(2023, 1, 2, 0, 0))

      query = TestModelOne.created_before(Time.utc(2023, 1, 1, 0, 2))
      expect(query.last).to eq(one)

      query = TestModelOne.created_before(Time.utc(2023, 1, 2))
      expect(query.last).to eq(two)
    end
  end

  describe "created_between" do
    it "finds records created between two time stamps" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 1, 1, 0, 3))
      three = TestModelOne.create!(name: "Three", created_at: Time.utc(2023, 1, 2, 0, 0))

      TestModelOne.store_created_id_for(Date.new(2023, 1, 1))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 2))

      expect(TestModelOne.created_between(Time.utc(2023, 1, 1, 0, 2), Time.utc(2023, 1, 1, 0, 5))).to eq([two])
    end
  end

  describe "changing created_at" do
    it "raises an error when changing created_at if the next created id was already calculated" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 1, 2))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 1))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 2))

      expect { one.update!(created_at: Time.utc(2023, 1, 2, 1)) }.to raise_error { CreatedId::CreatedAtChangedError }
      expect { one.update!(created_at: Time.utc(2023, 1, 3, 1)) }.to raise_error { CreatedId::CreatedAtChangedError }
      expect { one.update!(created_at: Time.utc(2022, 12, 31, 1)) }.to raise_error { CreatedId::CreatedAtChangedError }
      expect { two.update!(created_at: Time.utc(2023, 1, 1, 1)) }.to raise_error { CreatedId::CreatedAtChangedError }
      expect { two.update!(created_at: Time.utc(2022, 1, 1, 1)) }.to raise_error { CreatedId::CreatedAtChangedError }
    end

    it "does not raise an error when changing the created_at if the created id has not been calculated" do
      one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 1, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 1, 2))
      TestModelOne.store_created_id_for(Date.new(2023, 1, 1))

      expect { two.update!(created_at: Time.utc(2023, 1, 3, 1)) }.to_not raise_error
    end
  end
end
