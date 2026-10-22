# db/migrate/20261012041100_create_word_families.rb
class CreateWordFamilies < ActiveRecord::Migration[8.1]
  def change
    create_table :word_families, id: :uuid do |t|
      t.references :lesson, type: :uuid, null: false, foreign_key: true
      t.string :pattern, null: false
      t.jsonb :words, null: false, default: []
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

    add_index :word_families, :position
    add_index :word_families, :discarded_at
    add_index :word_families, [ :lesson_id, :position ]
  end
end
