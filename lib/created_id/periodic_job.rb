# frozen_string_literal: true

require "active_job"

module CreatedId
  # Job that enqueues a +CreatedId::IndexJob+ to index the previous hour for all
  # models that use CreatedId. This job takes no arguments so it can be run from a
  # periodic job scheduler.
  #
  # Schedule this job to run a few minutes after the top of every hour. The buffer
  # should be longer than your longest running write transaction so that all rows
  # created in the previous hour have been committed before it is indexed.
  class PeriodicJob < ActiveJob::Base
    # @return [void]
    def perform
      CreatedId::IndexJob.perform_later(CreatedId.coerce_hour(Time.now) - 3600)
    end
  end
end
