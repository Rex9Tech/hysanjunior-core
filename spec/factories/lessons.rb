FactoryBot.define do
  factory :lesson do
    sequence(:title) { |n| "Lesson #{n}" }
    level { 1 }
    unit { "Unit 1" }
    status { LessonConstants::Status::DRAFT }

    trait :with_song do
      after(:create) do |lesson|
        audio = create(
          :asset,
          type: AssetConstants::AssetType::GENERAL,
          format: AssetConstants::AssetFormat::AUDIO,
          extension: "mp3",
          assetable: lesson,
          parent_asset_id: nil,
          status: MediaConstants::Status::READY
        )
        create(
          :asset,
          type: AssetConstants::AssetType::SUBTITLE,
          format: AssetConstants::AssetFormat::SUBTITLE,
          extension: MediaConstants::SUBTITLE_EXT_SRT,
          assetable: lesson,
          parent_asset: audio,
          status: MediaConstants::Status::READY
        )
      end
    end

    trait :with_story do
      after(:create) do |lesson|
        video = create(
          :asset,
          type: AssetConstants::AssetType::GENERAL,
          format: AssetConstants::AssetFormat::VIDEO,
          extension: "mp4",
          assetable: lesson,
          parent_asset_id: nil,
          status: MediaConstants::Status::READY
        )
        create(
          :asset,
          type: AssetConstants::AssetType::SUBTITLE,
          format: AssetConstants::AssetFormat::SUBTITLE,
          extension: MediaConstants::SUBTITLE_EXT_SRT,
          assetable: lesson,
          parent_asset: video,
          status: MediaConstants::Status::READY
        )
      end
    end

    trait :with_vocabularies do
      after(:create) do |lesson|
        vocabulary = create(:vocabulary, lesson: lesson, vocab: "က", position: 0)
        create(
          :asset,
          type: AssetConstants::AssetType::GENERAL,
          format: AssetConstants::AssetFormat::IMAGE,
          extension: "png",
          assetable: vocabulary,
          parent_asset_id: nil,
          status: MediaConstants::Status::READY
        )
      end
    end

    trait :with_word_families do
      after(:create) do |lesson|
        create(
          :word_family,
          lesson: lesson,
          pattern: "..et",
          words: %w[net set pet],
          position: 0
        )
      end
    end

    trait :with_story_order do
      story_order do
        [
          "First we go to school.",
          "And I sit down in the classroom.",
          "And I opened the book."
        ]
      end
    end

    trait :with_build_the_sentences do
      # Matches :with_vocabularies default vocab "က" (one pair per vocabulary).
      after(:create) do |lesson|
        vocabs = lesson.vocabularies.ordered.pluck(:vocab)
        next if vocabs.blank?

        lesson.update!(
          build_the_sentences: vocabs.map { |vocab| { "vocab" => vocab, "sentence" => "I see #{vocab}." } }
        )
      end
    end

    trait :with_questions do
      after(:create) do |lesson|
        create(:question, :ready, questionable: lesson, title: "Which animal?", position: 0)
      end
    end

    trait :with_sort_health_choices do
      after(:create) do |lesson|
        create(:sort_health_choice, :ready, lesson: lesson, label: "Fruits", position: 0)
      end
    end

    trait :published do
      # Persist as draft first so media can attach before publish validation runs.
      status { LessonConstants::Status::DRAFT }
      with_song
      with_story
      with_vocabularies
      with_word_families
      with_story_order
      with_build_the_sentences
      with_questions
      with_sort_health_choices
      after(:create) do |lesson|
        lesson.update!(status: LessonConstants::Status::PUBLISHED)
      end
    end
  end
end
