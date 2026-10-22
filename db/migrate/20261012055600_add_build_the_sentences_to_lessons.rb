# db/migrate/20261012055600_add_build_the_sentences_to_lessons.rb
class AddBuildTheSentencesToLessons < ActiveRecord::Migration[8.1]
  def change
    add_column :lessons, :build_the_sentences, :jsonb, null: false, default: []
  end
end
