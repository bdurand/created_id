# frozen_string_literal: true

module CreatedId
  class Engine < Rails::Engine
    initialize do
      config.before_eager_load do
        require_relative "model"
      end
    end
  end
end
