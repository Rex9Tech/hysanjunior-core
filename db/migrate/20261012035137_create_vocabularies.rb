# db/migrate/20261012035137_create_vocabularies.rb
class CreateVocabularies < ActiveRecord::Migration[8.1]
  def change
    create_table :vocabularies, id: :uuid do |t|
      t.references :lesson, type: :uuid, null: false, foreign_key: true
      t.string :vocab, null: false
      t.string :vowel_symbol
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

    add_index :vocabularies, :position
    add_index :vocabularies, :discarded_at
    add_index :vocabularies, [ :lesson_id, :position ]
  end
end
