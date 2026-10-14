require "rails_helper"

RSpec.describe LessonService::GenerateStoryOrder do
  let(:user) { create(:user) }

  it "rejects lessons without a ready story SRT" do
    lesson = create(:lesson)

    expect {
      described_class.enqueue!(lesson: lesson, user: user)
    }.to raise_error(LessonService::GenerateStoryOrder::Error)
  end

  it "enqueues a generation job for lessons with story SRT" do
    lesson = create(:lesson, :with_story)
    allow(Lesson::GenerateStoryOrderJob).to receive(:perform_later).and_return(true)
    allow(NotificationService::Center).to receive(:notify)

    result = described_class.enqueue!(lesson: lesson, user: user)

    expect(result.operation_id).to be_present
    expect(Lesson::GenerateStoryOrderJob).to have_received(:perform_later).with(
      hash_including(lesson_id: lesson.id, user_id: user.id)
    )
  end

  it "parses AI output, saves story_order, and broadcasts the saved lines" do
    lesson = create(:lesson, :with_story)
    subtitle = lesson.story.subtitles.first
    allow(StorageService::Client).to receive(:download).with(subtitle.storage_key).and_return("1\n00:00:00,000 --> 00:00:01,000\nWe go to school.\n")
    allow(Ai::RunService).to receive(:execute_chat).and_return(
      {
        "choices" => [
          {
            "message" => {
              "content" => JSON.pretty_generate(
                [
                  "First we go to school.",
                  "And I sit down in the classroom."
                ]
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
      operation_id: "lesson_story_order:#{lesson.id}:test"
    )
    allow(service).to receive(:latest_run_id).and_return(SecureRandom.uuid)
    service.process!

    expect(lesson.reload.story_order).to eq(
      [
        "First we go to school.",
        "And I sit down in the classroom."
      ]
    )
    expect(NotificationService::Center).to have_received(:notify).with(
      hash_including(
        operation_status: NotificationConstants::OperationStatus::COMPLETED,
        data: hash_including(
          type: NotificationConstants::NotificationType::LESSON_STORY_ORDER_GENERATED,
          story_order: [
            "First we go to school.",
            "And I sit down in the classroom."
          ]
        )
      )
    )
  end
end
