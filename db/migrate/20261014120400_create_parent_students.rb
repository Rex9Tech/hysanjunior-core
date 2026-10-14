# db/migrate/20261014120400_create_parent_students.rb
class CreateParentStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :parent_students, id: :uuid do |t|
      t.references :parent, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :student, type: :uuid, null: false, foreign_key: { to_table: :users }

      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :parent_students, :discarded_at
    add_index :parent_students, [ :parent_id, :student_id ],
              unique: true,
              where: "discarded_at IS NULL",
              name: "index_parent_students_on_parent_student_kept"
  end
end
