# db/migrate/20261014120200_create_campus_memberships.rb
class CreateCampusMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :campus_memberships, id: :uuid do |t|
      t.references :campus, type: :uuid, null: false, foreign_key: { to_table: :campuses }
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :kind, null: false, default: "teacher_admin"

      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :discarded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :undiscarded_by, type: :uuid, foreign_key: { to_table: :users }

      t.datetime :discarded_at
      t.datetime :undiscarded_at

      t.timestamps
    end

    add_index :campus_memberships, :kind
    add_index :campus_memberships, :discarded_at
    add_index :campus_memberships, [ :campus_id, :user_id ],
              unique: true,
              where: "discarded_at IS NULL",
              name: "index_campus_memberships_on_campus_user_kept"
  end
end
