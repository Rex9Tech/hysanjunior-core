# db/migrate/20261014120300_create_class_enrollments.rb
class CreateClassEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :class_enrollments, id: :uuid do |t|
      t.references :school_class, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :status, null: false, default: "active"

      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :class_enrollments, :status
    add_index :class_enrollments, :discarded_at
    add_index :class_enrollments, :user_id,
              unique: true,
              where: "status = 'active' AND discarded_at IS NULL",
              name: "index_class_enrollments_one_active_per_student"
    add_index :class_enrollments, [ :school_class_id, :user_id ],
              unique: true,
              where: "discarded_at IS NULL",
              name: "index_class_enrollments_on_class_user_kept"
  end
end
