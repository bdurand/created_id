# frozen_string_literal: true

module CreatedId
  # This model stores the id ranges for other models by the hour. It is not meant to be
  # accessed directly.
  class IdRange < ActiveRecord::Base
    self.table_name = "created_ids"

    scope :for_class, ->(klass) { where(class_name: klass.base_class.name) }
    scope :created_before, ->(time) { where(hour: nil..time) }
    scope :created_after, ->(time) { where(hour: time...nil) }

    before_validation :set_hour

    validates :class_name, presence: true, length: {maximum: 100}
    validates :hour, presence: true
    validates :min_id, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates :max_id, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates_uniqueness_of :hour, scope: :class_name

    class << self
      # Get the minimum id for a class created in a given hour.
      #
      # @param klass [Class] The class to get the minimum id for.
      # @param time [Time] The hour to get the minimum id for.
      # @param allow_nil [Boolean] Whether to allow a nil value to be returned. If this is false,
      #   then the method will return 0 if no value is found.
      # @return [Integer, nil] The minimum id for the class created in the given hour.
      def min_id(klass, time, allow_nil: false)
        return nil if time.nil? && allow_nil

        id = for_class(klass).created_before(time).order(hour: :desc).first&.min_id
        id ||= 0 unless allow_nil
        id
      end

      # Get the maximum id for a class created in a given hour.
      #
      # @param klass [Class] The class to get the maximum id for.
      # @param time [Time] The hour to get the maximum id for.
      # @param allow_nil [Boolean] Whether to allow a nil value to be returned. If this is false,
      #  then the method will return the maximum possible id for the id column.
      # @return [Integer, nil] The maximum id for the class created in the given hour.
      def max_id(klass, time, allow_nil: false)
        return nil if time.nil? && allow_nil

        id = for_class(klass).created_after(CreatedId.coerce_hour(time)).order(hour: :asc).first&.max_id

        if id.nil? && !allow_nil
          col_limit = klass.columns.detect { |c| c.name == klass.primary_key }.limit
          id = if col_limit && col_limit > 0
            ((256**col_limit) / 2) - 1
          else
            klass.base_class.unscoped.maximum(:id).to_i
          end
        end

        id
      end

      # Get the minimum and maximum ids for a model created in a given hour. This
      # method is used in indexing the ranges.
      #
      # @param klass [Class] The class to get the id range for.
      # @param time [Time] The hour to get the id range for.
      # @return [Array<Integer>] The minimum and maximum ids for the class created in the given hour.
      def id_range(klass, time)
        klass = klass.base_class
        hour = CreatedId.coerce_hour(time)
        next_hour = hour + 3600

        finder = klass.unscoped.where(created_at: (hour...next_hour))

        prev_id = CreatedId::IdRange.min_id(klass, hour)
        if prev_id
          finder = finder.where(klass.arel_table[:id].gt(prev_id)) if prev_id > 0
        end

        next_id = CreatedId::IdRange.min_id(klass, next_hour + 3600)
        if next_id && (prev_id.nil? || next_id > prev_id)
          finder = finder.where(klass.arel_table[:id].lt(next_id))
        end

        [finder.minimum(:id), finder.maximum(:id)]
      end

      # Save the minimum and maximum ids for a class created in a given hour.
      #
      # @param klass [Class] The class to save the id range for.
      # @param time [Time] The hour to save the id range for.
      # @param min_id [Integer] The minimum id for the class created in the given hour.
      # @param max_id [Integer] The maximum id for the class created in the given hour.
      # @return [void]
      def save_created_id(klass, time, min_id, max_id)
        record = find_or_initialize_by(class_name: klass.base_class.name, hour: CreatedId.coerce_hour(time))
        record.min_id = min_id
        record.max_id = max_id
        record.save!
      end
    end

    private

    def set_hour
      self.hour = CreatedId.coerce_hour(hour) if hour && hour_changed?
    end
  end
end
