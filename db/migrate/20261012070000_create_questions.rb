# db/migrate/20261012070000_create_questions.rb
class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions, id: :uuid do |t|
      t.string :questionable_type, null: false
      t.uuid :questionable_id, null: false
      t.string :kind, null: false, default: "multiple_choice"
      t.string :title, null: false
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

    add_index :questions, [ :questionable_type, :questionable_id ], name: "index_questions_on_questionable"
    add_index :questions, :position
    add_index :questions, :discarded_at
    add_index :questions, :kind
    add_index :questions, [ :questionable_type, :questionable_id, :position ],
              name: "index_questions_on_questionable_and_position"
  end
end
