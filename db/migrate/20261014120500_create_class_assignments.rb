# db/migrate/20261014120500_create_class_assignments.rb
class CreateClassAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :class_assignments, id: :uuid do |t|
      t.references :school_class, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true

      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :class_assignments, :discarded_at
    add_index :class_assignments, [ :school_class_id, :user_id ],
              unique: true,
              where: "discarded_at IS NULL",
              name: "index_class_assignments_on_class_user_kept"
  end
end
