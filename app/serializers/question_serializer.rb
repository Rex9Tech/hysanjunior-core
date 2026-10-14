# app/serializers/question_serializer.rb

class QuestionSerializer < ApplicationSerializer
  attributes :id,
             :kind,
             :title,
             :position,
             :created_at,
             :updated_at

  attribute :options do |question|
    QuestionOptionSerializer.collection(question.options)
  end
end
