# frozen_string_literal: true

require "active_job"

module CreatedId
  # Job that indexes the id ranges for an hour on all of the models returned by
  # +CreatedId.models+.
  #
  # If indexing a model fails, the job is retried. On a retry, models that already have
  # an id range stored for the hour are skipped so that the job resumes with the model
  # that failed rather than re-indexing all of the models again. The first execution
  # always indexes every model so that the job can be used to recalculate an hour that
  # was already indexed.
  #
  # The current hour cannot be indexed since records can still be created in it. Enqueuing
  # the job for the current hour or a future hour raises a +CreatedId::IndexJob::IncompleteHourError+.
  # If the job is performed for an hour that has not ended, it is discarded without indexing
  # anything.
  #
  # @example Index the hour from 2:00 to 3:00 UTC
  #   CreatedId::IndexJob.perform_later(Time.utc(2025, 1, 1, 2))
  class IndexJob < ActiveJob::Base
    # Error raised when trying to index an hour that has not ended yet.
    class IncompleteHourError < ArgumentError
    end

    retry_on StandardError, attempts: 5, wait: ->(executions) { (executions**4) + 2 }

    # Declared after retry_on so that it takes precedence; retrying will not fix the error.
    discard_on IncompleteHourError

    before_enqueue :verify_hour_complete!

    # @param time [Time] The hour to index. This value is passed to +index_ids_for+ on each model.
    # @return [void]
    # @raise [IncompleteHourError] If the hour has not ended yet.
    def perform(time)
      verify_hour_complete!
      hour = CreatedId.coerce_hour(time)

      CreatedId.models.each do |model|
        next if executions > 1 && CreatedId::IdRange.for_class(model).where(hour: hour).exists?

        model.index_ids_for(time)
      end
    end

    private

    def verify_hour_complete!
      hour = CreatedId.coerce_hour(arguments.first)
      if hour >= CreatedId.coerce_hour(Time.now)
        raise IncompleteHourError, "Cannot index #{hour.iso8601} because the hour has not ended"
      end
    end
  end
end
