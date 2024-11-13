# frozen_string_literal: true

require_relative "spec_helper"

describe CreatedId do
  it "has a version number" do
    expect(CreatedId::VERSION).not_to be nil
  end

  describe "coerce_hour" do
    it "coerces a Time object to the hour in UTC" do
      time = Time.new(2017, 1, 1, 12, 34, 56, "+07:00")
      hour = CreatedId.coerce_hour(time)
      expect(hour).to eq(Time.utc(2017, 1, 1, 5))
      expect(hour.utc?).to be(true)
    end
  end

  describe "index_ids_for" do
    it "can calculates and stores the min id for records created on a date" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 18, 1, 0))
      four = TestModelOne.create!(name: "Four", created_at: Time.new(2023, 4, 18, 1, 1))

      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 0))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 1).in_time_zone("Pacific/Honolulu"))

      expect(CreatedId::IdRange.find_by(class_name: "TestModelOne", hour: Time.new(2023, 4, 18, 0)).min_id).to eq(one.id)
      expect(CreatedId::IdRange.find_by(class_name: "TestModelOne", hour: Time.new(2023, 4, 18, 1)).min_id).to eq(three.id)
    end

    it "does not store a min id if there are no records created the hour" do
      TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 1))
      expect(CreatedId::IdRange.find_by(class_name: "TestModelOne", hour: Time.new(2023, 4, 18, 1))).to be_nil
    end

    it "ignores the default scope when setting the min id" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1), deleted_at: Time.new(2023, 4, 18, 0, 2))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 0))
      expect(CreatedId::IdRange.find_by(class_name: "TestModelOne", hour: Time.new(2023, 4, 18, 0)).min_id).to eq(one.id)
    end

    it "always stores the ids for the base class" do
      one = TestModelThreeOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelTwo.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelThreeTwo.create!(name: "Three", created_at: Time.new(2023, 4, 18, 0, 3))
      TestModelTwo.index_ids_for(Time.new(2023, 4, 18, 0))
      TestModelThreeTwo.index_ids_for(Time.new(2023, 4, 18, 0))
      one_ids = CreatedId::IdRange.find_by(class_name: "TestModelThree", hour: Time.new(2023, 4, 18, 0))
      two_ids = CreatedId::IdRange.find_by(class_name: "TestModelTwo", hour: Time.new(2023, 4, 18, 0))
      expect(one_ids.min_id).to eq one.id
      expect(one_ids.max_id).to eq three.id
      expect(two_ids.min_id).to eq two.id
      expect(two_ids.max_id).to eq two.id
    end
  end

  describe "created_after" do
    it "finds records created after a time (inclusive" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 2, 0, 0))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 0).in_time_zone("Pacific/Honolulu"))

      query = TestModelOne.created_after(Time.new(2023, 4, 2, 0, 0)).order(:created_at)
      expect(query).to eq([three, one, two])

      query = TestModelOne.created_after(Time.new(2023, 4, 18, 0, 2)).order(:created_at)
      expect(query).to eq([two])
    end

    it "optimizes searches for records created after a time)" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 0))
      query = TestModelOne.created_after(Time.new(2023, 4, 18, 0, 2).in_time_zone("Pacific/Honolulu"))
      expect(query.to_sql).to include("\"id\" >= #{one.id}")
    end

    it "optimizes searches for records created after a time using the base class" do
      one = TestModelThreeOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      TestModelThree.index_ids_for(Time.new(2023, 4, 18, 0))
      query = TestModelThreeTwo.created_after(Time.new(2023, 4, 18, 0, 2).in_time_zone("Pacific/Honolulu"))
      expect(query.to_sql).to include("\"id\" >= #{one.id}")
    end

    it "finds records even if the ids are not indexed" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 2, 0, 0))

      query = TestModelOne.created_after(Time.new(2023, 4, 18, 0, 2)).order(:created_at)
      expect(query).to eq([two])
    end

    it "finds records even only some of the ids are indexed" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 18, 3))
      four = TestModelOne.create!(name: "Four", created_at: Time.new(2023, 4, 18, 4))

      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 1))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 3))

      query = TestModelOne.created_after(Time.new(2023, 4, 18, 2)).order(:id)
      expect(query.pluck(:id)).to match_array([two.id, three.id, four.id])
    end

    it "does not use an id filter if there are no ranges stored" do
      query = TestModelOne.created_after(Time.new(2023, 4, 18, 0, 2))
      expect(query.to_sql).to_not include("\"id\" >")
    end
  end

  describe "created_before" do
    it "finds records created before a time (exclusive)" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 19, 0, 0))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 0))

      query = TestModelOne.created_before(Time.new(2023, 4, 18, 0, 2)).order(:created_at)
      expect(query).to eq([one])

      query = TestModelOne.created_before(Date.new(2023, 4, 19, 0)).order(:created_at)
      expect(query).to eq([one, two])
    end

    it "optimizes searches for records created before a time" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 2, 2))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 2, 41))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 2))
      query = TestModelOne.created_before(Time.new(2023, 4, 18, 1, 30).in_time_zone("Pacific/Honolulu"))
      expect(query.to_sql).to include("\"id\" <= #{two.id}")
    end

    it "optimizes searches for records created before a time using the base class" do
      one = TestModelThreeOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 2, 2))
      two = TestModelThreeOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 2, 41))
      TestModelThree.index_ids_for(Time.new(2023, 4, 18, 2))
      query = TestModelThreeTwo.created_before(Time.new(2023, 4, 18, 1, 30).in_time_zone("Pacific/Honolulu"))
      expect(query.to_sql).to include("\"id\" <= #{two.id}")
    end

    it "finds records even if the ids are not indexed" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 19, 0, 0))

      query = TestModelOne.created_before(Time.new(2023, 4, 18, 0, 2)).order(:created_at)
      expect(query).to eq([one])

      query = TestModelOne.created_before(Time.new(2023, 4, 19)).order(:created_at)
      expect(query).to eq([one, two])
    end

    it "finds records even only some of the ids are indexed" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 18, 3))
      four = TestModelOne.create!(name: "Four", created_at: Time.new(2023, 4, 18, 4))

      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 1))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 3))

      query = TestModelOne.created_before(Time.new(2023, 4, 18, 4)).order(:id)
      expect(query.pluck(:id)).to match_array([one.id, two.id, three.id])
    end

    it "does not use an id filter if there are no ranges stored" do
      query = TestModelOne.created_before(Time.new(2023, 4, 18, 0, 2))
      expect(query.to_sql).to_not include("\"id\" <")
    end
  end

  describe "created_between" do
    it "finds records created between two time stamps" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 3))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 2, 0, 0))

      TestModelOne.index_ids_for(Date.new(2023, 4, 18))
      TestModelOne.index_ids_for(Date.new(2023, 4, 2))

      expect(TestModelOne.created_between(Time.new(2023, 4, 18, 0, 2), Time.new(2023, 4, 18, 0, 5))).to eq([two])
    end
  end

  describe "changing created_at" do
    it "raises an error when changing created_at would put the id outside an already calculated range" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 18, 3))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 1))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 2))
      TestModelOne.index_ids_for(Time.new(2023, 4, 18, 3))

      expect { two.update!(created_at: Time.new(2023, 4, 18, 3)) }.to raise_error { CreatedId::CreatedAtChangedError }
      expect { two.update!(created_at: Time.new(2023, 4, 18, 1)) }.to raise_error { CreatedId::CreatedAtChangedError }
    end

    it "does not raise an error when changing the created_at if the created id has not been calculated" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 2))
      TestModelOne.index_ids_for(Date.new(2023, 4, 18, 1))

      expect { two.update!(created_at: Time.new(2023, 4, 18, 3)) }.to_not raise_error
    end

    it "does not raise an error when changing the created_at if the id range does not change" do
      one = TestModelOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 1, 1))
      two = TestModelOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 1, 2))
      three = TestModelOne.create!(name: "Three", created_at: Time.new(2023, 4, 18, 1, 5))
      TestModelOne.index_ids_for(Date.new(2023, 4, 18, 1))

      expect { two.update!(created_at: Time.new(2023, 4, 18, 1, 3)) }.to_not raise_error
    end
  end
end
