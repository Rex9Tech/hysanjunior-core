require "rails_helper"

RSpec.describe LessonService::SyncQuestions do
  let(:lesson) { create(:lesson) }
  let(:user) { create(:user) }

  def image_asset
    create(
      :asset,
      type: AssetConstants::AssetType::GENERAL,
      format: AssetConstants::AssetFormat::IMAGE,
      extension: "png",
      parent_asset_id: nil,
      assetable: nil
    )
  end

  it "creates questions and options in array order and attaches picked images" do
    image = image_asset

    described_class.call(
      lesson,
      items: [
        {
          title: "Which animal?",
          options: [
            { text: "Cat", correct: true, image_asset_id: image.id },
            { text: "Dog", correct: false }
          ]
        }
      ],
      created_by: user
    )

    question = lesson.reload.questions.first
    expect(question.title).to eq("Which animal?")
    expect(question.kind).to eq(QuestionConstants::Kind::MULTIPLE_CHOICE)
    expect(question.options.map(&:text)).to eq(%w[Cat Dog])
    expect(question.options.map(&:correct)).to eq([ true, false ])
    expect(question.options.first.image.id).to eq(image.id)
  end

  it "allows multiple correct options" do
    described_class.call(
      lesson,
      items: [
        {
          title: "Pick animals",
          options: [
            { text: "Cat", correct: true },
            { text: "Dog", correct: true },
            { text: "Car", correct: false }
          ]
        }
      ],
      created_by: user
    )

    expect(lesson.reload.questions.first.options.count(&:correct?)).to eq(2)
  end

  it "destroys questions omitted from the sync list" do
    keep = create(:question, :ready, questionable: lesson, title: "Keep", position: 0)
    drop = create(:question, :ready, questionable: lesson, title: "Drop", position: 1)

    described_class.call(
      lesson,
      items: [
        {
          id: keep.id,
          title: "Keep",
          options: [
            { text: "A", correct: true },
            { text: "B", correct: false }
          ]
        }
      ],
      created_by: user
    )

    expect(lesson.reload.questions.pluck(:id)).to eq([ keep.id ])
    expect(Question.find_by(id: drop.id)).to be_nil
  end

  it "rejects questions that have options but no correct option" do
    expect {
      described_class.call(
        lesson,
        items: [
          {
            title: "Broken",
            options: [
              { text: "A", correct: false },
              { text: "B", correct: false }
            ]
          }
        ],
        created_by: user
      )
    }.to raise_error(LessonService::SyncQuestions::Error)
  end

  it "rejects providing both image_asset_id and image file" do
    file = fixture_file_upload("avatar.png", "image/png")

    expect {
      described_class.call(
        lesson,
        items: [
          {
            title: "Conflict",
            options: [
              { text: "A", correct: true, image_asset_id: image_asset.id, image: file },
              { text: "B", correct: false }
            ]
          }
        ],
        created_by: user
      )
    }.to raise_error(LessonService::SyncQuestions::Error)
  end
end
