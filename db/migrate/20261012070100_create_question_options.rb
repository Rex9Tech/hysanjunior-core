# db/migrate/20261012070100_create_question_options.rb
class CreateQuestionOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :question_options, id: :uuid do |t|
      t.references :question, type: :uuid, null: false, foreign_key: true
      t.string :text, null: false
      t.boolean :correct, null: false, default: false
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

    add_index :question_options, :position
    add_index :question_options, :discarded_at
    add_index :question_options, [ :question_id, :position ]
  end
end
