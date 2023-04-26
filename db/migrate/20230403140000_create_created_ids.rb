# frozen_string_literal: true

class CreateCreatedIds < ActiveRecord::Migration[5.0]
  def up
    create_table :created_ids do |t|
      t.string :class_name, null: false, limit: 100
      t.datetime :hour, null: false
      t.bigint :min_id, null: false
      t.bigint :max_id, null: false
    end

    add_index :created_ids, [:class_name, :hour], unique: true
  end
end
