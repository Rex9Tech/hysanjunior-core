require "rails_helper"

RSpec.describe LessonService::GenerateBuildTheSentences do
  let(:user) { create(:user) }

  it "rejects lessons without a ready story SRT" do
    lesson = create(:lesson, :with_vocabularies)

    expect {
      described_class.enqueue!(lesson: lesson, user: user)
    }.to raise_error(LessonService::GenerateBuildTheSentences::Error)
  end

  it "rejects lessons without vocabularies" do
    lesson = create(:lesson, :with_story)

    expect {
      described_class.enqueue!(lesson: lesson, user: user)
    }.to raise_error(LessonService::GenerateBuildTheSentences::Error)
  end

  it "enqueues a generation job for lessons with story SRT and vocabularies" do
    lesson = create(:lesson, :with_story, :with_vocabularies)
    allow(Lesson::GenerateBuildTheSentencesJob).to receive(:perform_later).and_return(true)
    allow(NotificationService::Center).to receive(:notify)

    result = described_class.enqueue!(lesson: lesson, user: user)

    expect(result.operation_id).to be_present
    expect(Lesson::GenerateBuildTheSentencesJob).to have_received(:perform_later).with(
      hash_including(lesson_id: lesson.id, user_id: user.id)
    )
  end

  it "parses AI output, saves build_the_sentences, and broadcasts the saved pairs" do
    lesson = create(:lesson, :with_story, :with_vocabularies)
    subtitle = lesson.story.subtitles.first
    allow(StorageService::Client).to receive(:download).with(subtitle.storage_key).and_return("1\n00:00:00,000 --> 00:00:01,000\nI see က.\n")
    allow(Ai::RunService).to receive(:execute_chat).and_return(
      {
        "choices" => [
          {
            "message" => {
              "content" => JSON.pretty_generate(
                [ { "vocab" => "က", "sentence" => "I see က." } ]
              )
            }
          }
        ]
      }
    )
    allow(NotificationService::Center).to receive(:notify)

    service = described_class.new(
      lesson: lesson,
      user: user,
      operation_id: "lesson_build_the_sentences:#{lesson.id}:test"
    )
    allow(service).to receive(:latest_run_id).and_return(SecureRandom.uuid)
    service.process!

    expect(lesson.reload.build_the_sentences).to eq(
      [ { "vocab" => "က", "sentence" => "I see က." } ]
    )
    expect(NotificationService::Center).to have_received(:notify).with(
      hash_including(
        operation_status: NotificationConstants::OperationStatus::COMPLETED,
        data: hash_including(
          type: NotificationConstants::NotificationType::LESSON_BUILD_THE_SENTENCES_GENERATED,
          build_the_sentences: [ { vocab: "က", sentence: "I see က." } ]
        )
      )
    )
  end
end
