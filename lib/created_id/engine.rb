# frozen_string_literal: true

module CreatedId
  class Engine < Rails::Engine
    config.before_eager_load do
      require_relative "id_range"
    end
  end
end
