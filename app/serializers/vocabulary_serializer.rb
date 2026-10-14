# app/serializers/vocabulary_serializer.rb

class VocabularySerializer < ApplicationSerializer
  attributes :id,
             :vocab,
             :vowel_symbol,
             :position,
             :created_at,
             :updated_at

  attribute :image_asset_id do |vocabulary|
    vocabulary.image_asset_id
  end

  attribute :image do |vocabulary|
    AssetSerializer.record(vocabulary.image)
  end
end
