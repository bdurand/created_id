# frozen_string_literal: true

require "spec_helper"

RSpec.describe CreatedId::IndexJob do
  def indexed_hours(klass)
    CreatedId::IdRange.where(class_name: klass.name).order(:hour).pluck(:hour).map(&:utc)
  end

  it "indexes the hour for all models" do
    TestModelOne.create!(name: "One", created_at: Time.utc(2023, 4, 18, 0, 1))
    TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 4, 18, 1, 1))
    TestModelTwo.create!(name: "One", created_at: Time.utc(2023, 4, 18, 0, 1))
    TestModelThreeOne.create!(name: "One", created_at: Time.utc(2023, 4, 18, 0, 1))

    CreatedId::IndexJob.perform_now(Time.utc(2023, 4, 18, 0, 30))

    expect(indexed_hours(TestModelOne)).to eq([Time.utc(2023, 4, 18, 0)])
    expect(indexed_hours(TestModelTwo)).to eq([Time.utc(2023, 4, 18, 0)])
    expect(indexed_hours(TestModelThree)).to eq([Time.utc(2023, 4, 18, 0)])
  end

  it "can be performed from serialized job data" do
    TestModelOne.create!(name: "One", created_at: Time.utc(2023, 4, 18, 0, 1))
    job_data = CreatedId::IndexJob.new(Time.utc(2023, 4, 18, 0)).serialize
    ActiveJob::Base.execute(JSON.parse(JSON.generate(job_data)))
    expect(indexed_hours(TestModelOne)).to eq([Time.utc(2023, 4, 18, 0)])
  end

  it "raises an error when enqueuing the current hour or a future hour" do
    expect { CreatedId::IndexJob.perform_later(Time.now) }.to raise_error(CreatedId::IndexJob::IncompleteHourError)
    expect { CreatedId::IndexJob.perform_later(Time.now + 3600) }.to raise_error(CreatedId::IndexJob::IncompleteHourError)
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
  end

  it "can enqueue the previous hour" do
    expect { CreatedId::IndexJob.perform_later(Time.now - 3600) }.to_not raise_error
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
  end

  it "discards the job without indexing when performed for the current hour" do
    TestModelOne.create!(name: "One")
    allow(TestModelOne).to receive(:index_ids_for).and_call_original

    CreatedId::IndexJob.perform_now(Time.now)

    expect(TestModelOne).to_not have_received(:index_ids_for)
    expect(CreatedId::IdRange.count).to eq(0)
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
  end

  it "re-indexes models that were already indexed on the first execution" do
    one = TestModelOne.create!(name: "One", created_at: Time.utc(2023, 4, 18, 0, 1))
    two = TestModelOne.create!(name: "Two", created_at: Time.utc(2023, 4, 18, 0, 2))
    CreatedId::IdRange.save_created_id(TestModelOne, Time.utc(2023, 4, 18, 0), one.id, one.id)

    CreatedId::IndexJob.perform_now(Time.utc(2023, 4, 18, 0))

    range = CreatedId::IdRange.find_by(class_name: "TestModelOne", hour: Time.utc(2023, 4, 18, 0))
    expect(range.min_id).to eq(one.id)
    expect(range.max_id).to eq(two.id)
  end

  it "does not re-index models that were already indexed when the job is retried" do
    TestModelOne.create!(name: "One", created_at: Time.utc(2023, 4, 18, 0, 1))
    TestModelTwo.create!(name: "One", created_at: Time.utc(2023, 4, 18, 0, 1))

    allow(TestModelOne).to receive(:index_ids_for).and_call_original
    allow(TestModelTwo).to receive(:index_ids_for).and_call_original
    calls = 0
    allow(TestModelThree).to receive(:index_ids_for) do
      calls += 1
      raise ActiveRecord::ConnectionNotEstablished, "boom" if calls == 1
    end

    job = CreatedId::IndexJob.new(Time.utc(2023, 4, 18, 0))
    job.perform_now

    expect(TestModelOne).to have_received(:index_ids_for).once
    expect(TestModelTwo).to_not have_received(:index_ids_for)
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)

    # Execute the retry from the job data that was enqueued.
    ActiveJob::Base.execute(JSON.parse(JSON.generate(job.serialize)))

    expect(TestModelOne).to have_received(:index_ids_for).once
    expect(TestModelThree).to have_received(:index_ids_for).twice
    expect(TestModelTwo).to have_received(:index_ids_for).once
    expect(indexed_hours(TestModelOne)).to eq([Time.utc(2023, 4, 18, 0)])
    expect(indexed_hours(TestModelTwo)).to eq([Time.utc(2023, 4, 18, 0)])
  end
end

RSpec.describe CreatedId::PeriodicJob do
  it "enqueues a job to index the previous hour" do
    allow(Time).to receive(:now).and_return(Time.utc(2023, 4, 18, 5, 10))
    allow(CreatedId::IndexJob).to receive(:perform_later)
    CreatedId::PeriodicJob.perform_now
    expect(CreatedId::IndexJob).to have_received(:perform_later).with(Time.utc(2023, 4, 18, 4))
  end
end
