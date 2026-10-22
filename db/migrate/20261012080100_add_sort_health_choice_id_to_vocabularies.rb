# db/migrate/20261012080100_add_sort_health_choice_id_to_vocabularies.rb
class AddSortHealthChoiceIdToVocabularies < ActiveRecord::Migration[8.1]
  def change
    add_reference :vocabularies, :sort_health_choice, type: :uuid, foreign_key: true, null: true
  end
end
