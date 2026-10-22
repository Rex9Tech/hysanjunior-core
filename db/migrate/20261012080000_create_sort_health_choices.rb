# db/migrate/20261012080000_create_sort_health_choices.rb
class CreateSortHealthChoices < ActiveRecord::Migration[8.1]
  def change
    create_table :sort_health_choices, id: :uuid do |t|
      t.references :lesson, type: :uuid, null: false, foreign_key: true
      t.string :label, null: false
      t.integer :position, null: false, default: 0

      # ===== AUDIT =====
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      # ===== SOFT DELETE =====
      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :sort_health_choices, :position
    add_index :sort_health_choices, :discarded_at
    add_index :sort_health_choices, [ :lesson_id, :position ]
  end
end
