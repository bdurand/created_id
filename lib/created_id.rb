# frozen_string_literal: true

require_relative "created_id/engine" if defined?(Rails::Engine)

module CreatedId
  extend ActiveSupport::Concern

  autoload :IdRange, "created_id/id_range"
  autoload :VERSION, "created_id/version"

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

    scope :created_after, ->(time) { created_id_range_query(time...nil) }
    scope :created_before, ->(time) { created_id_range_query(nil...time) }
    scope :created_between, ->(time_1, time_2) { created_id_range_query(time_1...time_2) }

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

    def created_id_range_query(time_range)
      finder = where(created_at: time_range)

      min_id = CreatedId::IdRange.min_id(self, time_range.begin, allow_nil: true) unless time_range.begin.nil?
      max_id = CreatedId::IdRange.max_id(self, time_range.end, allow_nil: true) unless time_range.end.nil?
      if min_id || max_id
        min_id ||= -Float::INFINITY
        max_id ||= Float::INFINITY
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
