# app/serializers/word_family_serializer.rb

class WordFamilySerializer < ApplicationSerializer
  attributes :id,
             :pattern,
             :words,
             :position,
             :created_at,
             :updated_at
end
