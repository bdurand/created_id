# frozen_string_literal: true

module CreatedId
  class Model < ActiveRecord::Base
    self.table_name = "created_ids"

    scope :for_class, ->(klass) { where(class_name: klass.base_class.name) }
    scope :created_before, ->(time) { where(arel_table[:hour].lteq(time)) }
    scope :created_after, ->(time) { where(arel_table[:hour].gt(time)) }

    before_validation :set_hour

    validates :class_name, presence: true, length: {maximum: 100}
    validates :hour, presence: true
    validates :min_id, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates_uniqueness_of :hour, scope: :class_name

    class << self
      def min_id(klass, time)
        for_class(klass).created_before(time).order(hour: :desc).first&.min_id || 0
      end

      # Calculate the minimum possible id for entries created on a date.
      def max_id(klass, time)
        id = for_class(klass).created_after(time + 3600).order(hour: :asc).first&.min_id

        unless id
          col_limit = klass.columns.detect { |c| c.name == klass.primary_key }.limit
          id = if col_limit && col_limit > 0
            ((256**col_limit) / 2) - 1
          else
            klass.base_class.unscoped.maximum(:id).to_i + 1
          end
        end

        id
      end

      def calculate_min_id(klass, time)
        klass = klass.base_class
        hour = coerce_hour(time)
        next_hour = hour + 3600
        prev_hour = hour - 3600

        finder = klass.unscoped.where(created_at: (hour...next_hour))

        prev_id = CreatedId::Model.min_id(self, prev_hour)
        if prev_id
          finder = finder.where(klass.arel_table[:id].gt(prev_id)) if prev_id > 0

          next_id = CreatedId::Model.min_id(self, next_hour)
          if next_id
            finder = finder.where(klass.arel_table[:id].lt(next_id)) if next_id > prev_id
          end
        end

        finder.minimum(:id)
      end

      def save_created_id(klass, time, min_id)
        record = find_or_initialize_by(class_name: klass.name, hour: coerce_hour(time))
        record.min_id = min_id
        record.save!
      end

      def coerce_hour(time)
        time = time.to_time.utc
        Time.utc(time.year, time.month, time.day, time.hour)
      end
    end

    private

    def set_hour
      self.hour = self.class.coerce_hour(hour) if hour && hour_changed?
    end
  end
end
