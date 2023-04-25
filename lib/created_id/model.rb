# frozen_string_literal: true

module CreatedId
  class Model < ActiveRecord::Base
    self.table_name = "created_ids"

    scope :for_class, ->(klass) { where(class_name: klass.base_class.name) }
    scope :created_before, ->(date) { where(arel_table[:created_on].lteq(date)) }
    scope :created_after, ->(date) { where(arel_table[:created_on].gt(date)) }

    validates :class_name, presence: true, length: {maximum: 100}
    validates :created_on, presence: true
    validates :min_id, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates_uniqueness_of :created_on, scope: :class_name

    class << self
      def min_id(klass, date)
        for_class(klass).created_before(date).order(created_on: :desc).first&.min_id || 0
      end

      # Calculate the minimum possible id for entries created on a date.
      def max_id(klass, date)
        id = for_class(klass).created_after(date).order(created_on: :asc).first&.min_id

        unless id
          col_limit = columns.detect { |c| c.name == klass.primary_key }.limit
          id = if col_limit
            ((2**col_limit) / 2) - 1
          else
            klass.base_class.unscoped.maximum(:id) + 1
          end
        end

        id
      end

      def calculate_min_id(klass, date)
        klass = klass.base_class

        finder = klass.unscoped.where(created_at: (date...date + 1))

        prev_id = CreatedId::Model.min_id(self, date - 1)
        if prev_id
          finder = finder.where(klass.arel_table[:id].gt(prev_id)) if prev_id > 0

          next_id = CreatedId::Model.min_id(self, date + 1)
          if next_id
            finder = finder.where(klass.arel_table[:id].lt(next_id)) if next_id > prev_id
          end
        end

        finder.minimum(:id)
      end

      def save_created_id(klass, date, min_id)
        record = find_or_initialize_by(class_name: klass.name, created_on: date)
        record.min_id = min_id
        record.save!
      end
    end
  end
end
