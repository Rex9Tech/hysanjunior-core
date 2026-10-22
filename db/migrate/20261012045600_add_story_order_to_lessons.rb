# db/migrate/20261012045600_add_story_order_to_lessons.rb
class AddStoryOrderToLessons < ActiveRecord::Migration[8.1]
  def change
    add_column :lessons, :story_order, :jsonb, null: false, default: []
  end
end
