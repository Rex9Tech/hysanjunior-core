require "rails_helper"

RSpec.describe LessonService::AttachStory do
  let(:lesson) { create(:lesson) }
  let(:user) { create(:user) }

  def video_with_srt
    video = create(
      :asset,
      type: AssetConstants::AssetType::GENERAL,
      format: AssetConstants::AssetFormat::VIDEO,
      extension: "mp4",
      parent_asset_id: nil,
      assetable: nil
    )
    create(
      :asset,
      type: AssetConstants::AssetType::SUBTITLE,
      format: AssetConstants::AssetFormat::SUBTITLE,
      extension: "srt",
      parent_asset: video,
      assetable: nil
    )
    video
  end

  it "attaches an existing video asset with SRT" do
    video = video_with_srt

    described_class.call(lesson, story_asset_id: video.id, created_by: user)

    expect(lesson.reload.story.id).to eq(video.id)
    expect(video.reload.assetable).to eq(lesson)
  end

  it "rejects video without SRT" do
    video = create(
      :asset,
      format: AssetConstants::AssetFormat::VIDEO,
      extension: "mp4",
      parent_asset_id: nil,
      assetable: nil
    )

    expect {
      described_class.call(lesson, story_asset_id: video.id, created_by: user)
    }.to raise_error(LessonService::AttachStory::Error)
  end

  it "links a picked thumbnail and skips auto thumbnail generation" do
    video = video_with_srt
    thumb = create(
      :asset,
      type: AssetConstants::AssetType::GENERAL,
      format: AssetConstants::AssetFormat::IMAGE,
      extension: "png",
      parent_asset_id: nil,
      assetable: nil
    )
    allow(Media::GenerateVideoThumbnailJob).to receive(:perform_later)

    described_class.call(
      lesson,
      story_asset_id: video.id,
      thumbnail_asset_id: thumb.id,
      created_by: user
    )

    expect(video.reload.thumbnail.id).to eq(thumb.id)
    expect(Media::GenerateVideoThumbnailJob).not_to have_received(:perform_later)
  end

  it "enqueues thumbnail generation when no custom thumbnail is provided" do
    video = video_with_srt
    allow(Media::GenerateVideoThumbnailJob).to receive(:perform_later)

    described_class.call(lesson, story_asset_id: video.id, created_by: user)

    expect(Media::GenerateVideoThumbnailJob).to have_received(:perform_later).with(asset_id: video.id)
  end

  it "clears the current story when clear is requested" do
    lesson = create(:lesson, :with_story)
    story_id = lesson.story.id

    described_class.call(lesson, clear: true, created_by: user)

    expect(lesson.reload.story).to be_nil
    expect(Asset.find(story_id).assetable).to be_nil
  end
end
