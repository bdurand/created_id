# frozen_string_literal: true

require_relative "created_id/engine" if defined?(Rails::Engine)

module CreatedId
  extend ActiveSupport::Concern

  autoload :IdRange, "created_id/id_range"
  autoload :VERSION, "created_id/version"

  OPEN_RANGE_SUPPORTED = Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7")

  class CreatedAtChangedError < StandardError
  end

  class << self
    # Coerce a time to the beginning of the hour in UTC.
    def coerce_hour(time)
      time = time.to_time.utc
      Time.utc(time.year, time.month, time.day, time.hour)
    end
  end

  included do
    unless defined?(ActiveRecord) && self < ActiveRecord::Base
      raise ArgmentError, "CreatedId can only be included in ActiveRecord models"
    end

    scope :created_after, ->(time) { created_between(time, nil) }
    scope :created_before, ->(time) { created_between(nil, time) }

    before_save :verify_created_at_created_id!, if: :created_at_changed?
  end

  class_methods do
    # Index the id range for the records created in the given hour.
    #
    # @param time [Time] The hour to store the id range for. The value will be coerced to the beginning of the hour.
    # @return [void]
    def index_ids_for(time)
      min_id, max_id = CreatedId::IdRange.id_range(self, time)
      if min_id && max_id
        CreatedId::IdRange.save_created_id(self, time, min_id, max_id)
      end
    end

    # Get records created in the given time range. The time range is based on the
    # created_at column and is inclusive of the start time and exclusive of the end time.
    #
    # @param start_time [Time, nil] The start of the time range. If nil, the range is open-ended.
    # @param end_time [Time, nil] The end of the time range. If nil, the range is open-ended.
    # @return [ActiveRecord::Relation] The records created in the given time range.
    def created_between(start_time, end_time)
      finder = where(created_at: start_time...end_time)

      min_id = CreatedId::IdRange.min_id(self, start_time, allow_nil: OPEN_RANGE_SUPPORTED)
      max_id = CreatedId::IdRange.max_id(self, end_time, allow_nil: OPEN_RANGE_SUPPORTED)
      if min_id || max_id
        finder = finder.where(primary_key => min_id..max_id)
      end

      finder
    end
  end

  private

  # Verify that the created_at value is within the range of the created_ids for that time period.
  #
  # @return [void]
  # @raise [CreatedId::CreatedAtChangedError] If the created_at value is outside the range of the created_ids for that time period.
  def verify_created_at_created_id!
    # This is the normal case where created at is set to the current time on insert.
    return if id.nil? && created_at_was.nil?

    new_hour = CreatedId.coerce_hour(created_at || Time.now)
    range = CreatedId::IdRange.for_class(self.class).find_by(hour: new_hour)

    if range && (id < range.min_id || id > range.max_id)
      raise CreatedAtChangedError, "created_at cannot be changed outside of the range of the created_ids for that time period"
    end
  end
end
