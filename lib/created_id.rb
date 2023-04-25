# frozen_string_literal: true

module CreatedId
  class CreatedAtChangedError < StandardError
  end

  def self.included(base)
    unless defined?(ActiveRecord) && base < ActiveRecord::Base
      raise ArgmentError, "CreatedId can only be included in ActiveRecord models"
    end

    base.extend(ClassMethods)

    # Require here so we don't mess up loading the activerecord gem.
    require_relative "created_id/model"

    base.scope :created_after, ->(time) { where(arel_table[:created_at].gteq(time).and(arel_table[primary_key].gteq(CreatedId::Model.min_id(self, time)))) }
    base.scope :created_before, ->(time) { where(arel_table[:created_at].lt(time).and(arel_table[primary_key].lt(CreatedId::Model.max_id(self, time)))) }
    base.scope :created_between, ->(time_1, time_2) { created_after(time_1).created_before(time_2) }

    base.before_save :verify_created_at_created_id!, if: :created_at_changed?
  end

  module ClassMethods
    def store_created_id_for(time)
      min_id = CreatedId::Model.calculate_min_id(self, time)
      if min_id
        CreatedId::Model.save_created_id(self, time, min_id)
      end
    end
  end

  private

  def verify_created_at_created_id!
    return if id.nil? && created_at_was.nil?

    new_date = (created_at || Time.now).utc.to_date
    prev_date = created_at_was.utc.to_date if created_at_was
    finder = CreatedId::Model.for_class(self.class)

    if finder.created_after(new_date).exists?
      raise CreatedAtChangedError, "created_at cannot be changed after the created id for the date has been stored"
    end

    if prev_date && prev_date != new_date && finder.created_after(prev_date).exists?
      raise CreatedAtChangedError, "created_at cannot be changed after the created id for the previous value has been stored"
    end
  end
end

require_relative "created_id/version"
