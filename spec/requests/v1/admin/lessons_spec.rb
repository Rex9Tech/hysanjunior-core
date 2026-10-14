require "rails_helper"

RSpec.describe "V1 Admin Lessons API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "lessons", :read, :create, :update, :delete)
  end

  describe "GET /v1/admin/lessons" do
    it "returns paginated lessons" do
      create_list(:lesson, 3)

      get "/v1/admin/lessons", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end

    it "filters by status, level, and unit" do
      create(:lesson, :published, title: "Alpha", level: 1, unit: "Unit A")
      create(:lesson, title: "Beta", status: LessonConstants::Status::DRAFT, level: 2, unit: "Unit B")

      get "/v1/admin/lessons", params: {
        status: LessonConstants::Status::PUBLISHED,
        level: 1,
        unit: "Unit A"
      }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "title")).to eq("Alpha")
    end

    it "searches by title and unit" do
      create(:lesson, title: "Greetings", unit: "Unit 1")
      create(:lesson, title: "Numbers", unit: "Unit 2")

      get "/v1/admin/lessons", params: { search: "greet" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "title")).to eq("Greetings")
    end

    it "lists discarded lessons when discarded=true" do
      kept = create(:lesson, title: "Kept")
      discarded = create(:lesson, title: "Trashed")
      discarded.discard

      get "/v1/admin/lessons", params: { discarded: true }, headers: headers

      expect(response).to have_http_status(:ok)
      titles = response_data.map { |row| row.dig("attributes", "title") }
      expect(titles).to contain_exactly("Trashed")
      expect(titles).not_to include(kept.title)
    end
  end

  describe "GET /v1/admin/lessons/:id" do
    it "returns lesson details including song, story, and vocabularies" do
      lesson = create(:lesson, :with_song, :with_story, :with_vocabularies, title: "Inspect me", level: 3, unit: "Unit 3")

      get "/v1/admin/lessons/#{lesson.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "title")).to eq("Inspect me")
      expect(response_data.dig("attributes", "song_asset_id")).to eq(lesson.song.id)
      expect(response_data.dig("attributes", "song", "id")).to eq(lesson.song.id)
      expect(response_data.dig("attributes", "song", "attributes", "format")).to eq("audio")
      expect(response_data.dig("attributes", "song", "attributes", "children", "subtitles")).to be_present
      expect(response_data.dig("attributes", "story_asset_id")).to eq(lesson.story.id)
      expect(response_data.dig("attributes", "story", "attributes", "format")).to eq("video")
      expect(response_data.dig("attributes", "story", "attributes", "children", "subtitles")).to be_present
      expect(response_data.dig("attributes", "vocabularies").size).to eq(1)
      expect(response_data.dig("attributes", "vocabularies", 0, "attributes", "vocab")).to eq("က")
      expect(response_data.dig("attributes", "vocabularies", 0, "attributes", "image_asset_id")).to be_present
    end

    it "returns 404 for missing lesson" do
      get "/v1/admin/lessons/#{SecureRandom.uuid}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /v1/admin/lessons" do
    it "creates a lesson defaulting status to draft" do
      post "/v1/admin/lessons", params: {
        lesson: { title: "New Lesson", level: 1, unit: "Unit 1" }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "title")).to eq("New Lesson")
      expect(response_data.dig("attributes", "status")).to eq(LessonConstants::Status::DRAFT)
      expect(response_data.dig("attributes", "song_asset_id")).to be_nil
    end

    it "rejects invalid status" do
      post "/v1/admin/lessons", params: {
        lesson: { title: "Bad", level: 1, unit: "Unit 1", status: "archived" }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "links an existing audio asset with SRT as the lesson song" do
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

      post "/v1/admin/lessons", params: {
        lesson: {
          title: "With Song",
          level: 1,
          unit: "Unit 1",
          song_asset_id: audio.id
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "song_asset_id")).to eq(audio.id)
      expect(audio.reload.assetable_type).to eq("Lesson")
    end

    it "rejects linking audio without an SRT subtitle" do
      audio = create(
        :asset,
        type: AssetConstants::AssetType::GENERAL,
        format: AssetConstants::AssetFormat::AUDIO,
        extension: "mp3",
        parent_asset_id: nil,
        assetable: nil
      )

      post "/v1/admin/lessons", params: {
        lesson: { title: "No SRT", level: 1, unit: "Unit 1", song_asset_id: audio.id }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response_status["error"]).to include("SRT")
    end

    it "uploads audio and srt in one request and enqueues compression" do
      stub_const("MediaConstants::MEDIA_CONTAINER_ENABLED", true)
      audio_file = fixture_file_upload("clip.m4a", "audio/mp4")
      srt_file = fixture_file_upload("captions.srt", "application/x-subrip")
      allow(Media::CompressMediaJob).to receive(:perform_later)
      allow(StorageService::Client).to receive(:upload).and_return(
        {
          storage_key: "admin/general_clip.m4a",
          url: "https://cdn.example.com/clip.m4a",
          bytes: 100,
          format: "m4a",
          resource_type: "video"
        },
        {
          storage_key: "admin/subtitle_clip.srt",
          url: "https://cdn.example.com/clip.srt",
          bytes: 20,
          format: "srt",
          resource_type: "raw"
        }
      )

      post "/v1/admin/lessons", params: {
        lesson: { title: "Uploaded Song", level: 1, unit: "Unit 1" },
        audio: audio_file,
        srt: srt_file
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "song_asset_id")).to be_present
      expect(response_data.dig("attributes", "song", "attributes", "format")).to eq("audio")
      expect(response_data.dig("attributes", "song", "attributes", "children", "subtitles").size).to eq(1)
      expect(Media::CompressMediaJob).to have_received(:perform_later).with(
        asset_id: response_data.dig("attributes", "song_asset_id")
      )
    end

    it "rejects providing both song_asset_id and upload files" do
      audio = create(
        :asset,
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
        parent_asset: audio
      )
      audio_file = fixture_file_upload("clip.m4a", "audio/mp4")
      srt_file = fixture_file_upload("captions.srt", "application/x-subrip")

      post "/v1/admin/lessons", params: {
        lesson: { title: "Conflict", level: 1, unit: "Unit 1", song_asset_id: audio.id },
        audio: audio_file,
        srt: srt_file
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "links an existing video asset with SRT as the lesson story" do
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
      allow(Media::GenerateVideoThumbnailJob).to receive(:perform_later)

      post "/v1/admin/lessons", params: {
        lesson: {
          title: "With Story",
          level: 1,
          unit: "Unit 1",
          story_asset_id: video.id
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "story_asset_id")).to eq(video.id)
      expect(video.reload.assetable_type).to eq("Lesson")
      expect(Media::GenerateVideoThumbnailJob).to have_received(:perform_later).with(asset_id: video.id)
    end

    it "uploads video and video_srt and enqueues compress plus thumbnail" do
      stub_const("MediaConstants::MEDIA_CONTAINER_ENABLED", true)
      video_file = fixture_file_upload("clip.mp4", "video/mp4")
      srt_file = fixture_file_upload("captions.srt", "application/x-subrip")
      allow(Media::CompressMediaJob).to receive(:perform_later)
      allow(Media::GenerateVideoThumbnailJob).to receive(:perform_later)
      allow(StorageService::Client).to receive(:upload).and_return(
        {
          storage_key: "admin/general_clip.mp4",
          url: "https://cdn.example.com/clip.mp4",
          bytes: 100,
          format: "mp4",
          resource_type: "video"
        },
        {
          storage_key: "admin/subtitle_clip.srt",
          url: "https://cdn.example.com/clip.srt",
          bytes: 20,
          format: "srt",
          resource_type: "raw"
        }
      )

      post "/v1/admin/lessons", params: {
        lesson: { title: "Uploaded Story", level: 1, unit: "Unit 1" },
        video: video_file,
        video_srt: srt_file
      }, headers: headers

      expect(response).to have_http_status(:created)
      story_id = response_data.dig("attributes", "story_asset_id")
      expect(story_id).to be_present
      expect(response_data.dig("attributes", "story", "attributes", "format")).to eq("video")
      expect(Media::CompressMediaJob).to have_received(:perform_later).with(asset_id: story_id)
      expect(Media::GenerateVideoThumbnailJob).to have_received(:perform_later).with(asset_id: story_id)
    end

    it "uploads story with custom thumbnail and skips auto thumbnail generation" do
      stub_const("MediaConstants::MEDIA_CONTAINER_ENABLED", true)
      video_file = fixture_file_upload("clip.mp4", "video/mp4")
      srt_file = fixture_file_upload("captions.srt", "application/x-subrip")
      thumb_file = fixture_file_upload("avatar.png", "image/png")
      allow(Media::CompressMediaJob).to receive(:perform_later)
      allow(Media::GenerateVideoThumbnailJob).to receive(:perform_later)
      allow(StorageService::Client).to receive(:upload).and_return(
        {
          storage_key: "admin/general_clip.mp4",
          url: "https://cdn.example.com/clip.mp4",
          bytes: 100,
          format: "mp4",
          resource_type: "video"
        },
        {
          storage_key: "admin/subtitle_clip.srt",
          url: "https://cdn.example.com/clip.srt",
          bytes: 20,
          format: "srt",
          resource_type: "raw"
        },
        {
          storage_key: "admin/thumbnail_clip.png",
          url: "https://cdn.example.com/thumb.png",
          bytes: 10,
          format: "png",
          resource_type: "image"
        }
      )

      post "/v1/admin/lessons", params: {
        lesson: { title: "Story With Thumb", level: 1, unit: "Unit 1" },
        video: video_file,
        video_srt: srt_file,
        thumbnail: thumb_file
      }, headers: headers

      expect(response).to have_http_status(:created)
      story_id = response_data.dig("attributes", "story_asset_id")
      expect(response_data.dig("attributes", "story", "attributes", "children", "thumbnail")).to be_present
      expect(Media::CompressMediaJob).to have_received(:perform_later).with(asset_id: story_id)
      expect(Media::GenerateVideoThumbnailJob).not_to have_received(:perform_later)
    end

    it "creates nested vocabularies with picked images" do
      image = create(
        :asset,
        type: AssetConstants::AssetType::GENERAL,
        format: AssetConstants::AssetFormat::IMAGE,
        extension: "png",
        parent_asset_id: nil,
        assetable: nil
      )

      post "/v1/admin/lessons", params: {
        lesson: {
          title: "With Vocab",
          level: 1,
          unit: "Unit 1",
          vocabularies: [
            { vocab: "က", vowel_symbol: "ာ", image_asset_id: image.id },
            { vocab: "ခ" }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      vocabs = response_data.dig("attributes", "vocabularies")
      expect(vocabs.size).to eq(2)
      expect(vocabs.first.dig("attributes", "vocab")).to eq("က")
      expect(vocabs.first.dig("attributes", "vowel_symbol")).to eq("ာ")
      expect(vocabs.first.dig("attributes", "image_asset_id")).to eq(image.id)
      expect(vocabs.second.dig("attributes", "vocab")).to eq("ခ")
      expect(vocabs.second.dig("attributes", "image_asset_id")).to be_nil
    end

    it "creates nested word families on the same create request" do
      post "/v1/admin/lessons", params: {
        lesson: {
          title: "With Families",
          level: 1,
          unit: "Unit 1",
          word_families: [
            { pattern: "..et", words: %w[net set pet] },
            { pattern: "..ed", words: %w[loaded needed] }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      families = response_data.dig("attributes", "word_families")
      expect(families.size).to eq(2)
      expect(families.first.dig("attributes", "pattern")).to eq("..et")
      expect(families.first.dig("attributes", "words")).to eq(%w[net set pet])
    end

    it "creates story_order on the same create request" do
      post "/v1/admin/lessons", params: {
        lesson: {
          title: "With Story Order",
          level: 1,
          unit: "Unit 1",
          story_order: [
            "First we go to school.",
            "And I sit down in the classroom."
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "story_order")).to eq(
        [
          "First we go to school.",
          "And I sit down in the classroom."
        ]
      )
    end

    it "creates build_the_sentences on the same create request" do
      post "/v1/admin/lessons", params: {
        lesson: {
          title: "With Build Sentences",
          level: 1,
          unit: "Unit 1",
          build_the_sentences: [
            { vocab: "cat", sentence: "I see the cat." },
            { vocab: "book", sentence: "She opens the book." }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "build_the_sentences")).to eq(
        [
          { "vocab" => "cat", "sentence" => "I see the cat." },
          { "vocab" => "book", "sentence" => "She opens the book." }
        ]
      )
    end

    it "creates nested multiple-choice questions on the same create request" do
      post "/v1/admin/lessons", params: {
        lesson: {
          title: "With Questions",
          level: 1,
          unit: "Unit 1",
          questions: [
            {
              title: "Which animal?",
              options: [
                { text: "Cat", correct: true },
                { text: "Dog", correct: false }
              ]
            }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      questions = response_data.dig("attributes", "questions")
      expect(questions.size).to eq(1)
      expect(questions.first.dig("attributes", "title")).to eq("Which animal?")
      options = questions.first.dig("attributes", "options")
      expect(options.map { |row| row.dig("attributes", "text") }).to eq(%w[Cat Dog])
      expect(options.map { |row| row.dig("attributes", "correct") }).to eq([ true, false ])
    end

    it "creates nested sort_health_choices with vocab items on the same create request" do
      post "/v1/admin/lessons", params: {
        lesson: {
          title: "With Sort Health",
          level: 1,
          unit: "Unit 1",
          sort_health_choices: [
            {
              label: "Fruits",
              items: [
                { vocab: "apple" },
                { vocab: "banana" }
              ]
            }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      groups = response_data.dig("attributes", "sort_health_choices")
      expect(groups.size).to eq(1)
      expect(groups.first.dig("attributes", "label")).to eq("Fruits")
      items = groups.first.dig("attributes", "items")
      expect(items.map { |row| row.dig("attributes", "vocab") }).to eq(%w[apple banana])
      expect(response_data.dig("attributes", "vocabularies")).to eq([])
    end
  end

  describe "POST /v1/admin/lessons/:id/create_word_families" do
    it "queues async generation when story SRT exists" do
      lesson = create(:lesson, :with_story)
      allow(Lesson::GenerateWordFamiliesJob).to receive(:perform_later).and_return(true)
      allow(NotificationService::Center).to receive(:notify)

      post "/v1/admin/lessons/#{lesson.id}/create_word_families", headers: headers

      expect(response).to have_http_status(:accepted)
      expect(response_data["operation_id"]).to be_present
      expect(Lesson::GenerateWordFamiliesJob).to have_received(:perform_later)
    end

    it "rejects generation when story SRT is missing" do
      lesson = create(:lesson)

      post "/v1/admin/lessons/#{lesson.id}/create_word_families", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /v1/admin/lessons/:id/create_story_order" do
    it "queues async generation when story SRT exists" do
      lesson = create(:lesson, :with_story)
      allow(Lesson::GenerateStoryOrderJob).to receive(:perform_later).and_return(true)
      allow(NotificationService::Center).to receive(:notify)

      post "/v1/admin/lessons/#{lesson.id}/create_story_order", headers: headers

      expect(response).to have_http_status(:accepted)
      expect(response_data["operation_id"]).to be_present
      expect(Lesson::GenerateStoryOrderJob).to have_received(:perform_later)
    end

    it "rejects generation when story SRT is missing" do
      lesson = create(:lesson)

      post "/v1/admin/lessons/#{lesson.id}/create_story_order", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /v1/admin/lessons/:id/create_build_the_sentences" do
    it "queues async generation when story SRT and vocabularies exist" do
      lesson = create(:lesson, :with_story, :with_vocabularies)
      allow(Lesson::GenerateBuildTheSentencesJob).to receive(:perform_later).and_return(true)
      allow(NotificationService::Center).to receive(:notify)

      post "/v1/admin/lessons/#{lesson.id}/create_build_the_sentences", headers: headers

      expect(response).to have_http_status(:accepted)
      expect(response_data["operation_id"]).to be_present
      expect(Lesson::GenerateBuildTheSentencesJob).to have_received(:perform_later)
    end

    it "rejects generation when story SRT is missing" do
      lesson = create(:lesson, :with_vocabularies)

      post "/v1/admin/lessons/#{lesson.id}/create_build_the_sentences", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects generation when vocabularies are missing" do
      lesson = create(:lesson, :with_story)

      post "/v1/admin/lessons/#{lesson.id}/create_build_the_sentences", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /v1/admin/lessons/:id" do
    it "updates lesson fields" do
      lesson = create(
        :lesson,
        :with_song,
        :with_story,
        :with_vocabularies,
        :with_word_families,
        :with_story_order,
        :with_build_the_sentences,
        :with_questions,
        :with_sort_health_choices,
        status: LessonConstants::Status::DRAFT
      )

      patch "/v1/admin/lessons/#{lesson.id}", params: {
        lesson: {
          title: "Published Lesson",
          status: LessonConstants::Status::PUBLISHED,
          level: 2,
          unit: "Unit 2"
        }
      }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "title")).to eq("Published Lesson")
      expect(response_data.dig("attributes", "status")).to eq(LessonConstants::Status::PUBLISHED)
      expect(response_data.dig("attributes", "level")).to eq(2)
    end

    it "updates nested questions without changing word families" do
      lesson = create(:lesson, :with_word_families, :with_questions)

      patch "/v1/admin/lessons/#{lesson.id}", params: {
        lesson: {
          questions: [
            {
              title: "Updated question",
              options: [
                { text: "Yes", correct: true },
                { text: "No", correct: false },
                { text: "Maybe", correct: true }
              ]
            }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:ok)
      questions = response_data.dig("attributes", "questions")
      expect(questions.size).to eq(1)
      expect(questions.first.dig("attributes", "title")).to eq("Updated question")
      options = questions.first.dig("attributes", "options")
      expect(options.map { |row| row.dig("attributes", "correct") }).to eq([ true, false, true ])
      expect(lesson.reload.word_families.count).to eq(1)
    end

    it "updates story_order without changing other nested lists" do
      lesson = create(:lesson, :with_word_families, story_order: [ "Old sentence." ])

      patch "/v1/admin/lessons/#{lesson.id}", params: {
        lesson: {
          story_order: [
            "First we go to school.",
            "And I sit down in the classroom."
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "story_order")).to eq(
        [
          "First we go to school.",
          "And I sit down in the classroom."
        ]
      )
      expect(lesson.reload.word_families.count).to eq(1)
    end

    it "updates build_the_sentences without changing other nested lists" do
      lesson = create(
        :lesson,
        :with_word_families,
        build_the_sentences: [ { "vocab" => "old", "sentence" => "Old sentence." } ]
      )

      patch "/v1/admin/lessons/#{lesson.id}", params: {
        lesson: {
          build_the_sentences: [
            { vocab: "cat", sentence: "I see the cat." }
          ]
        }
      }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "build_the_sentences")).to eq(
        [ { "vocab" => "cat", "sentence" => "I see the cat." } ]
      )
      expect(lesson.reload.word_families.count).to eq(1)
    end

    it "blocks publish when the lesson has no ready song or story" do
      lesson = create(:lesson, status: LessonConstants::Status::DRAFT)

      patch "/v1/admin/lessons/#{lesson.id}", params: {
        lesson: { status: LessonConstants::Status::PUBLISHED }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lesson.reload.status).to eq(LessonConstants::Status::DRAFT)
    end

    it "blocks publish when only song is ready" do
      lesson = create(:lesson, :with_song, status: LessonConstants::Status::DRAFT)

      patch "/v1/admin/lessons/#{lesson.id}", params: {
        lesson: { status: LessonConstants::Status::PUBLISHED }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lesson.reload.status).to eq(LessonConstants::Status::DRAFT)
    end

    it "blocks publish when song and story are ready but vocabularies lack images" do
      lesson = create(:lesson, :with_song, :with_story, status: LessonConstants::Status::DRAFT)
      create(:vocabulary, lesson: lesson, vocab: "က", position: 0)

      patch "/v1/admin/lessons/#{lesson.id}", params: {
        lesson: { status: LessonConstants::Status::PUBLISHED }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lesson.reload.status).to eq(LessonConstants::Status::DRAFT)
    end
  end

  describe "DELETE /v1/admin/lessons/:id" do
    it "soft-deletes the lesson" do
      lesson = create(:lesson)

      delete "/v1/admin/lessons/#{lesson.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(lesson.reload.discarded?).to be(true)
    end
  end

  describe "POST /v1/admin/lessons/:id/undiscard" do
    it "restores a discarded lesson" do
      lesson = create(:lesson)
      lesson.discard

      post "/v1/admin/lessons/#{lesson.id}/undiscard", headers: headers

      expect(response).to have_http_status(:ok)
      expect(lesson.reload.discarded?).to be(false)
      expect(response_data.dig("attributes", "title")).to eq(lesson.title)
    end
  end

  describe "authorization" do
    it "rejects ordinary users without admin role" do
      user = create(:user)
      user_token = jwt_for(user)
      allow(CacheService).to receive(:read).and_return(user_token)

      get "/v1/admin/lessons", headers: authorization_headers(user_token)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
