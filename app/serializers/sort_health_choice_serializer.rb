# app/serializers/sort_health_choice_serializer.rb

class SortHealthChoiceSerializer < ApplicationSerializer
  attributes :id,
             :label,
             :position,
             :created_at,
             :updated_at

  attribute :items do |choice|
    VocabularySerializer.collection(choice.vocabularies)
  end
end
