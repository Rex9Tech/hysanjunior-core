require "rails_helper"

RSpec.describe Lesson, type: :model do
  it "is valid with title, level, unit, and status" do
    lesson = build(:lesson)
    expect(lesson).to be_valid
  end

  it "requires title, unit, and a positive level" do
    lesson = build(:lesson, title: nil, unit: nil, level: 0)
    expect(lesson).not_to be_valid
    expect(lesson.errors[:title]).to be_present
    expect(lesson.errors[:unit]).to be_present
    expect(lesson.errors[:level]).to be_present
  end

  it "only allows draft, published, and unpublished statuses" do
    lesson = build(:lesson, status: "archived")
    expect(lesson).not_to be_valid
    expect(lesson.errors[:status]).to be_present
  end

  it "searches by title or unit" do
    create(:lesson, title: "Hello", unit: "Unit A")
    create(:lesson, title: "World", unit: "Unit B")

    expect(described_class.search_term("hello").pluck(:title)).to eq([ "Hello" ])
    expect(described_class.search_term("Unit B").pluck(:title)).to eq([ "World" ])
  end

  it "requires all nested content before publish" do
    lesson = create(:lesson)
    lesson.status = LessonConstants::Status::PUBLISHED

    expect(lesson).not_to be_valid
    expect(lesson.errors[:base].size).to be >= 8
  end

  it "rejects publish when sort health choices are missing" do
    lesson = create(
      :lesson,
      :with_song,
      :with_story,
      :with_vocabularies,
      :with_word_families,
      :with_story_order,
      :with_build_the_sentences,
      :with_questions
    )
    lesson.status = LessonConstants::Status::PUBLISHED

    expect(lesson).not_to be_valid
    expect(lesson.sort_health_choices_ready?).to be(false)
  end

  it "publishes when all media, nested content, questions, and sort health choices are ready" do
    lesson = create(
      :lesson,
      :with_song,
      :with_story,
      :with_vocabularies,
      :with_word_families,
      :with_story_order,
      :with_build_the_sentences,
      :with_questions,
      :with_sort_health_choices
    )
    lesson.status = LessonConstants::Status::PUBLISHED

    expect(lesson).to be_valid
    expect(lesson.questions_ready?).to be(true)
    expect(lesson.sort_health_choices_ready?).to be(true)
  end

  it "keeps lesson vocab list separate from sort-health vocab items" do
    lesson = create(:lesson, :with_vocabularies, :with_sort_health_choices)

    expect(lesson.vocabularies.count).to eq(1)
    expect(lesson.vocabularies.first.sort_health_choice_id).to be_nil
    expect(lesson.sort_health_choices.first.vocabularies.count).to eq(1)
    expect(lesson.sort_health_choices.first.vocabularies.first.sort_health_choice_id).to be_present
  end
end
