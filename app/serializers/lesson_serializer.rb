# app/serializers/lesson_serializer.rb

class LessonSerializer < ApplicationSerializer
  attributes :id,
             :title,
             :level,
             :unit,
             :status,
             :story_order,
             :build_the_sentences,
             :discarded_at,
             :created_at,
             :updated_at

  attribute :song_asset_id do |lesson|
    lesson.song_asset_id
  end

  attribute :song do |lesson|
    AssetSerializer.record(lesson.song)
  end

  attribute :story_asset_id do |lesson|
    lesson.story_asset_id
  end

  attribute :story do |lesson|
    AssetSerializer.record(lesson.story)
  end

  attribute :vocabularies do |lesson|
    VocabularySerializer.collection(lesson.vocabularies)
  end

  attribute :word_families do |lesson|
    WordFamilySerializer.collection(lesson.word_families)
  end

  attribute :questions do |lesson|
    QuestionSerializer.collection(lesson.questions)
  end

  attribute :sort_health_choices do |lesson|
    SortHealthChoiceSerializer.collection(lesson.sort_health_choices)
  end
end
