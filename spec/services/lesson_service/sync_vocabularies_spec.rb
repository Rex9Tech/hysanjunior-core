require "rails_helper"

RSpec.describe LessonService::SyncVocabularies do
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

  it "creates vocabulary rows in array order and attaches picked images" do
    first_image = image_asset
    second_image = image_asset

    described_class.call(
      lesson,
      items: [
        { vocab: "က", vowel_symbol: "ာ", image_asset_id: first_image.id },
        { vocab: "ခ", image_asset_id: second_image.id }
      ],
      created_by: user
    )

    rows = lesson.reload.vocabularies
    expect(rows.map(&:vocab)).to eq([ "က", "ခ" ])
    expect(rows.map(&:position)).to eq([ 0, 1 ])
    expect(rows.first.vowel_symbol).to eq("ာ")
    expect(rows.first.image.id).to eq(first_image.id)
    expect(rows.second.image.id).to eq(second_image.id)
  end

  it "destroys vocabularies omitted from the sync list" do
    keep = create(:vocabulary, lesson: lesson, vocab: "Keep", position: 0)
    drop = create(:vocabulary, lesson: lesson, vocab: "Drop", position: 1)
    image = image_asset

    described_class.call(
      lesson,
      items: [ { id: keep.id, vocab: "Keep", image_asset_id: image.id } ],
      created_by: user
    )

    expect(lesson.reload.vocabularies.pluck(:id)).to eq([ keep.id ])
    expect(Vocabulary.find_by(id: drop.id)).to be_nil
  end

  it "rejects providing both image_asset_id and image file" do
    file = fixture_file_upload("avatar.png", "image/png")

    expect {
      described_class.call(
        lesson,
        items: [ { vocab: "က", image_asset_id: image_asset.id, image: file } ],
        created_by: user
      )
    }.to raise_error(LessonService::SyncVocabularies::Error)
  end

  it "uploads an image file for a vocabulary item" do
    file = fixture_file_upload("avatar.png", "image/png")
    allow(StorageService::Client).to receive(:upload).and_return(
      {
        storage_key: "admin/general_avatar.png",
        url: "https://cdn.example.com/avatar.png",
        bytes: 10,
        format: "png",
        resource_type: "image"
      }
    )

    described_class.call(
      lesson,
      items: [ { vocab: "ဂ", image: file } ],
      created_by: user
    )

    vocabulary = lesson.reload.vocabularies.first
    expect(vocabulary.vocab).to eq("ဂ")
    expect(vocabulary.image).to be_present
    expect(vocabulary.image.format).to eq(AssetConstants::AssetFormat::IMAGE)
  end
end
