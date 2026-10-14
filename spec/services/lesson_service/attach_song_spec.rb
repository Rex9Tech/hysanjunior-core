require "rails_helper"

RSpec.describe LessonService::AttachSong do
  let(:lesson) { create(:lesson) }
  let(:user) { create(:user) }

  def audio_with_srt
    audio = create(
      :asset,
      type: AssetConstants::AssetType::GENERAL,
      format: AssetConstants::AssetFormat::AUDIO,
      extension: "mp3",
      parent_asset_id: nil,
      assetable: nil
    )
    create(
      :asset,
      type: AssetConstants::AssetType::SUBTITLE,
      format: AssetConstants::AssetFormat::SUBTITLE,
      extension: "srt",
      parent_asset: audio,
      assetable: nil
    )
    audio
  end

  it "attaches an existing audio asset with SRT" do
    audio = audio_with_srt

    described_class.call(lesson, song_asset_id: audio.id, created_by: user)

    expect(lesson.reload.song.id).to eq(audio.id)
    expect(audio.reload.assetable).to eq(lesson)
  end

  it "rejects audio without SRT" do
    audio = create(
      :asset,
      format: AssetConstants::AssetFormat::AUDIO,
      extension: "mp3",
      parent_asset_id: nil,
      assetable: nil
    )

    expect {
      described_class.call(lesson, song_asset_id: audio.id, created_by: user)
    }.to raise_error(LessonService::AttachSong::Error)
  end

  it "clears the current song when clear is requested" do
    lesson = create(:lesson, :with_song)
    song_id = lesson.song.id

    described_class.call(lesson, clear: true, created_by: user)

    expect(lesson.reload.song).to be_nil
    expect(Asset.find(song_id).assetable).to be_nil
  end
end
