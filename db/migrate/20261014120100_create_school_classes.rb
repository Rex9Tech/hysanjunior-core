# db/migrate/20261014120100_create_school_classes.rb
class CreateSchoolClasses < ActiveRecord::Migration[8.1]
  def change
    create_table :school_classes, id: :uuid do |t|
      t.references :campus, type: :uuid, null: false, foreign_key: { to_table: :campuses }
      t.string :name, null: false
      t.integer :level, null: false
      t.string :status, null: false, default: "active"

      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :school_classes, :name
    add_index :school_classes, :level
    add_index :school_classes, :status
    add_index :school_classes, :discarded_at
    add_index :school_classes, [ :campus_id, :level, :name ],
              unique: true,
              where: "discarded_at IS NULL",
              name: "index_school_classes_on_campus_level_name_kept"
  end
end
