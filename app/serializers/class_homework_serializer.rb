# app/serializers/class_homework_serializer.rb

class ClassHomeworkSerializer < ApplicationSerializer
  attributes :id,
             :school_class_id,
             :lesson_id,
             :activity_keys,
             :play_song_at_first,
             :play_story_at_first,
             :title,
             :due_on,
             :created_at,
             :updated_at

  attribute :activity_labels do |homework|
    homework.activity_labels
  end

  attribute :lesson do |homework|
    {
      id: homework.lesson.id,
      title: homework.lesson.title,
      level: homework.lesson.level,
      unit: homework.lesson.unit,
      status: homework.lesson.status
    }
  end

  attribute :school_class do |homework|
    {
      id: homework.school_class.id,
      name: homework.school_class.name,
      level: homework.school_class.level,
      campus_id: homework.school_class.campus_id
    }
  end
end
