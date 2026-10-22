require "rails_helper"

RSpec.describe ClassHomework, type: :model do
  it "allows the same lesson to be assigned multiple times to one class" do
    school_class = create(:school_class)
    lesson = create(:lesson)

    first = create(:class_homework, school_class: school_class, lesson: lesson)
    second = create(:class_homework, school_class: school_class, lesson: lesson)

    expect(first).to be_persisted
    expect(second).to be_persisted
    expect(school_class.class_homeworks.count).to eq(2)
  end

  it "rejects empty, duplicate, or unknown activity keys" do
    homework = build(:class_homework, activity_keys: [])
    expect(homework).not_to be_valid

    homework.activity_keys = [
      CampusConstants::HomeworkActivity::LISTEN_AND_TAP,
      CampusConstants::HomeworkActivity::LISTEN_AND_TAP
    ]
    expect(homework).not_to be_valid

    homework.activity_keys = [ "not_a_real_activity" ]
    expect(homework).not_to be_valid
  end

  it "exposes ordered activity labels" do
    homework = build(
      :class_homework,
      activity_keys: [
        CampusConstants::HomeworkActivity::BUILD_THE_SENTENCES,
        CampusConstants::HomeworkActivity::LISTEN_AND_TAP
      ]
    )

    expect(homework.activity_labels).to eq([
      "Build the sentences",
      "Listen And Tap"
    ])
  end
end
