# db/migrate/20261009121007_create_lessons.rb
class CreateLessons < ActiveRecord::Migration[8.1]
  def change
    create_table :lessons, id: :uuid do |t|
      t.string :title, null: false
      t.integer :level, null: false
      t.string :unit, null: false
      t.string :status, null: false, default: "draft"

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

    add_index :lessons, :title
    add_index :lessons, :level
    add_index :lessons, :unit
    add_index :lessons, :status
    add_index :lessons, :discarded_at
    add_index :lessons, [ :level, :unit ]
  end
end
