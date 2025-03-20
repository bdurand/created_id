# frozen_string_literal: true

require_relative "../spec_helper"

describe CreatedId::IdRange do
  describe "min_id" do
    it "returns the minimum id for the specified base class and hour" do
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 1, 5), 1, 100)
      expect(CreatedId::IdRange.min_id(TestModelThreeOne, Time.utc(2017, 1, 1, 5, 40))).to eq(1)
    end

    it "returns 0 if there are no records for the specified base class" do
      TestModelThreeOne.create!(name: "One")
      expect(CreatedId::IdRange.min_id(TestModelThreeOne, Time.utc(2017, 1, 1, 5, 40))).to eq(0)
    end

    it "returns the minimum id for the specified base class and hour even if records are out of order" do
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 1, 5), 1, 100)
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 1, 6), 99, 200)
      expect(CreatedId::IdRange.min_id(TestModelThreeOne, Time.utc(2017, 1, 1, 5, 40))).to eq(1)
      expect(CreatedId::IdRange.min_id(TestModelThreeOne, Time.utc(2017, 1, 1, 6, 40))).to eq(99)
    end
  end

  describe "max_id" do
    it "returns the maximum id for the specified base class and hour" do
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 1, 5), 1, 100)
      expect(CreatedId::IdRange.max_id(TestModelThreeOne, Time.utc(2017, 1, 1, 5, 40))).to eq(100)
    end

    it "returns the maximum id for the specified base class if there are no records for the specified base class" do
      one = TestModelThreeOne.create!(name: "One")
      two = TestModelThreeTwo.create!(name: "Two")
      expect(CreatedId::IdRange.max_id(TestModelThreeOne, Time.utc(2017, 1, 1, 5, 40))).to eq(two.id)
    end

    it "returns the maximum id for the specified base class and hour even if records are out of order" do
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 1, 5), 1, 100)
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 1, 6), 99, 200)
      expect(CreatedId::IdRange.max_id(TestModelThreeOne, Time.utc(2017, 1, 1, 5, 40))).to eq(100)
      expect(CreatedId::IdRange.max_id(TestModelThreeOne, Time.utc(2017, 1, 1, 6, 40))).to eq(200)
    end
  end

  describe "id_range" do
    it "returns the minimum and maximum ids for the specified base class and hour" do
      one = TestModelThreeOne.create!(name: "One", created_at: Time.new(2023, 4, 18, 0, 1))
      two = TestModelThreeOne.create!(name: "Two", created_at: Time.new(2023, 4, 18, 0, 2))
      three = TestModelThreeTwo.create!(name: "Three", created_at: Time.new(2023, 4, 18, 0, 3))
      four = TestModelThreeOne.create!(name: "Four", created_at: Time.new(2023, 4, 18, 1, 1))
      expect(CreatedId::IdRange.id_range(TestModelThreeOne, Time.new(2023, 4, 18, 0))).to eq([one.id, three.id])
    end

    it "uses the existing data to help calculate the minimum and maximum ids" do
      one = TestModelThreeOne.create!(name: "One", created_at: Time.utc(2023, 4, 18, 0, 1))
      two = TestModelThreeOne.create!(name: "Two", created_at: Time.utc(2023, 4, 18, 0, 2))
      three = TestModelThreeTwo.create!(name: "Three", created_at: Time.utc(2023, 4, 18, 1, 3))
      four = TestModelThreeOne.create!(name: "Four", created_at: Time.utc(2023, 4, 18, 1, 4))
      five = TestModelThreeOne.create!(name: "Five", created_at: Time.utc(2023, 4, 18, 2, 1))
      six = TestModelThreeOne.create!(name: "Six", created_at: Time.utc(2023, 4, 18, 2, 2))
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2023, 4, 18, 0), one.id, two.id)
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2023, 4, 18, 2), five.id, six.id)
      expect(CreatedId::IdRange.id_range(TestModelThreeOne, Time.utc(2023, 4, 18, 1))).to eq([three.id, four.id])
    end
  end

  describe "save_created_id" do
    it "creates a new record for the specified base class and hour" do
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 2, 4), 1, 10)
      CreatedId::IdRange.save_created_id(TestModelOne, Time.utc(2017, 1, 2, 5), 1, 10)
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 2, 5, 15), 11, 100)
      expect(CreatedId::IdRange.count).to eq(3)
      record = CreatedId::IdRange.last
      expect(record.hour).to eq(Time.utc(2017, 1, 2, 5))
      expect(record.min_id).to eq(11)
      expect(record.max_id).to eq(100)
    end

    it "updates an existing record for the specified base class and hour" do
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 2, 4), 1, 10)
      CreatedId::IdRange.save_created_id(TestModelOne, Time.utc(2017, 1, 2, 5), 1, 10)
      CreatedId::IdRange.save_created_id(TestModelThree, Time.utc(2017, 1, 2, 4, 15), 11, 100)
      expect(CreatedId::IdRange.count).to eq(2)
      record = CreatedId::IdRange.first
      expect(record.hour).to eq(Time.utc(2017, 1, 2, 4))
      expect(record.min_id).to eq(11)
      expect(record.max_id).to eq(100)
    end
  end
end
