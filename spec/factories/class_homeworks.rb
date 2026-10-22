FactoryBot.define do
  factory :class_homework do
    school_class
    lesson
    activity_keys do
      [
        CampusConstants::HomeworkActivity::LISTEN_AND_TAP,
        CampusConstants::HomeworkActivity::SPEAK_AND_RECORD
      ]
    end
    play_song_at_first { false }
    play_story_at_first { false }
  end
end
