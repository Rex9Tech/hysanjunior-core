require "rails_helper"

RSpec.describe LessonService::SyncSortHealthChoices do
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

  it "creates groups and vocabulary items without polluting the lesson vocab list" do
    image = image_asset

    described_class.call(
      lesson,
      items: [
        {
          label: "Fruits",
          items: [
            { vocab: "apple", image_asset_id: image.id },
            { vocab: "banana" }
          ]
        }
      ],
      created_by: user
    )

    choice = lesson.reload.sort_health_choices.first
    expect(choice.label).to eq("Fruits")
    expect(choice.vocabularies.map(&:vocab)).to eq(%w[apple banana])
    expect(choice.vocabularies.first.image.id).to eq(image.id)
    expect(lesson.vocabularies).to be_empty
    expect(Vocabulary.for_sort_health_choices.where(lesson_id: lesson.id).count).to eq(2)
  end

  it "destroys groups omitted from the sync list" do
    keep = create(:sort_health_choice, :ready, lesson: lesson, label: "Keep", position: 0)
    drop = create(:sort_health_choice, :ready, lesson: lesson, label: "Drop", position: 1)

    described_class.call(
      lesson,
      items: [
        {
          id: keep.id,
          label: "Keep",
          items: [ { vocab: "apple" } ]
        }
      ],
      created_by: user
    )

    expect(lesson.reload.sort_health_choices.pluck(:id)).to eq([ keep.id ])
    expect(SortHealthChoice.find_by(id: drop.id)).to be_nil
  end

  it "rejects a blank group label" do
    expect {
      described_class.call(
        lesson,
        items: [ { label: " ", items: [ { vocab: "apple" } ] } ],
        created_by: user
      )
    }.to raise_error(LessonService::SyncSortHealthChoices::Error)
  end
end
