# db/migrate/20261014120600_create_class_homeworks.rb
class CreateClassHomeworks < ActiveRecord::Migration[8.1]
  def change
    create_table :class_homeworks, id: :uuid do |t|
      t.references :school_class, type: :uuid, null: false, foreign_key: true
      t.references :lesson, type: :uuid, null: false, foreign_key: true
      t.jsonb :activity_keys, null: false, default: []
      t.boolean :play_song_at_first, null: false, default: false
      t.boolean :play_story_at_first, null: false, default: false
      t.string :title
      t.date :due_on

      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :class_homeworks, :discarded_at
    add_index :class_homeworks, :due_on
    add_index :class_homeworks, [ :school_class_id, :created_at ]
    add_index :class_homeworks, :activity_keys, using: :gin
  end
end
