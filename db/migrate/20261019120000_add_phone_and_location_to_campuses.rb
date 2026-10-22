# db/migrate/20261019120000_add_phone_and_location_to_campuses.rb
class AddPhoneAndLocationToCampuses < ActiveRecord::Migration[8.1]
  def up
    add_column :campuses, :phone, :string unless column_exists?(:campuses, :phone)
    add_column :campuses, :location, :text unless column_exists?(:campuses, :location)
  end

  def down
    remove_column :campuses, :phone if column_exists?(:campuses, :phone)
    remove_column :campuses, :location if column_exists?(:campuses, :location)
  end
end
