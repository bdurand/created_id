# frozen_string_literal: true

require_relative "spec_helper"

describe CreatedId do
  it "has a version number" do
    expect(CreatedId::VERSION).not_to be nil
  end

  describe "store_created_id_for" do
    it "can calculates and stores the min id for records created on a date" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 18, 1, 0))
      four = TestModelOne.create!(name: "Four", created_at: Time.new(2023, 4, 18, 1, 1))

      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 0))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 1).in_time_zone("Pacific/Honolulu"))

      expect(CreatedId::Model.find_by(class_name: "TestModelOne", hour: Time.new(2023, 4, 18, 0)).min_id).to eq(one.id)
      expect(CreatedId::Model.find_by(class_name: "TestModelOne", hour: Time.new(2023, 4, 18, 1)).min_id).to eq(three.id)
    end

    it "does not store a min id if there are no records created the hour" do
      TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 1))
      expect(CreatedId::Model.find_by(class_name: "TestModelOne", hour: Time.new(2023, 4, 18, 1))).to be_nil
    end

    it "ignores the default scope when setting the min id" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1), deleted_at: Time.new(2023, 4, 18, 0, 2))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 0))
      expect(CreatedId::Model.find_by(class_name: "TestModelOne", hour: Time.new(2023, 4, 18, 0)).min_id).to eq(one.id)
    end
  end

  describe "created_after" do
    it "finds records created after a time" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 2, 0, 0))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 0).in_time_zone("Pacific/Honolulu"))

      query = TestModelOne.created_after(Time.new(2023, 4, 18, 0, 2))
      expect(query.first).to eq(two)
    end

    it "optimizes searches for records created after a time" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 0))
      query = TestModelOne.created_after(Time.new(2023, 4, 18, 0, 2).in_time_zone("Pacific/Honolulu"))
      expect(query.to_sql).to include("\"id\" >= #{one.id}")
    end

    it "finds records even if the min id is not stored" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 2, 0, 0))

      query = TestModelOne.created_after(Time.new(2023, 4, 18, 0, 2))
      expect(query.first).to eq(two)
    end

    it "uses zero as the id if there are no ranges stored" do
      query = TestModelOne.created_after(Time.new(2023, 4, 18, 0, 2))
      expect(query.to_sql).to include("\"id\" >= 0")
    end
  end

  describe "created_before" do
    it "finds records created before a time" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 19, 0, 0))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 0))

      query = TestModelOne.created_before(Time.new(2023, 4, 18, 0, 2))
      expect(query.last).to eq(one)

      query = TestModelOne.created_before(Date.new(2023, 4, 19, 0))
      expect(query.last).to eq(two)
    end

    it "optimizes searches for records created before a time" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 2, 2))
      two = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 3, 2))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 2))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 3))
      query = TestModelOne.created_before(Time.new(2023, 4, 18, 1, 30).in_time_zone("Pacific/Honolulu"))
      expect(query.to_sql).to include("\"id\" < #{two.id}")
    end

    it "finds records even if the min id is not stored" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 19, 0, 0))

      query = TestModelOne.created_before(Time.new(2023, 4, 18, 0, 2))
      expect(query.last).to eq(one)

      query = TestModelOne.created_before(Time.new(2023, 4, 19))
      expect(query.last).to eq(two)
    end

    it "uses the max id if there are no ranges stored" do
      query = TestModelOne.created_before(Time.new(2023, 4, 18, 0, 2))
      expect(query.to_sql).to include("\"id\" < 1")
    end
  end

  describe "created_between" do
    it "finds records created between two time stamps" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 3))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 2, 0, 0))

      TestModelOne.store_created_id_for(Date.new(2023, 4, 18))
      TestModelOne.store_created_id_for(Date.new(2023, 4, 2))

      expect(TestModelOne.created_between(Time.new(2023, 4, 18, 0, 2), Time.new(2023, 4, 18, 0, 5))).to eq([two])
    end
  end

  describe "changing created_at" do
    it "raises an error when changing created_at if the next created id was already calculated" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 2))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 1))
      TestModelOne.store_created_id_for(Time.new(2023, 4, 18, 2))

      expect { one.update!(created_at: Time.new(2023, 4, 18, 2)) }.to raise_error { CreatedId::CreatedAtChangedError }
      expect { one.update!(created_at: Time.new(2023, 4, 18, 3)) }.to raise_error { CreatedId::CreatedAtChangedError }
      expect { one.update!(created_at: Time.new(2023, 4, 18, 0)) }.to raise_error { CreatedId::CreatedAtChangedError }
      expect { two.update!(created_at: Time.new(2023, 4, 18, 1)) }.to raise_error { CreatedId::CreatedAtChangedError }
      expect { two.update!(created_at: Time.new(2022, 1, 1, 1)) }.to raise_error { CreatedId::CreatedAtChangedError }
    end

    it "does not raise an error when changing the created_at if the created id has not been calculated" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 2))
      TestModelOne.store_created_id_for(Date.new(2023, 4, 18, 1))

      expect { two.update!(created_at: Time.new(2023, 4, 18, 3)) }.to_not raise_error
    end
  end
end
