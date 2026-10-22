# app/serializers/question_option_serializer.rb

class QuestionOptionSerializer < ApplicationSerializer
  attributes :id,
             :text,
             :correct,
             :position,
             :created_at,
             :updated_at

  attribute :image_asset_id do |option|
    option.image_asset_id
  end

  attribute :image do |option|
    AssetSerializer.record(option.image)
  end
end
