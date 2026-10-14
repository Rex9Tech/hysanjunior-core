# db/migrate/20261014120000_create_campuses.rb
class CreateCampuses < ActiveRecord::Migration[8.1]
  def change
    create_table :campuses, id: :uuid do |t|
      t.string :name, null: false
      t.string :code
      t.string :status, null: false, default: "active"

      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :campuses, :name
    add_index :campuses, :code, unique: true, where: "code IS NOT NULL AND discarded_at IS NULL"
    add_index :campuses, :status
    add_index :campuses, :discarded_at
  end
end
