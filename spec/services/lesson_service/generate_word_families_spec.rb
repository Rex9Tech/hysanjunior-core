require "rails_helper"

RSpec.describe LessonService::GenerateWordFamilies do
  let(:user) { create(:user) }

  it "rejects lessons without a ready story SRT" do
    lesson = create(:lesson)

    expect {
      described_class.enqueue!(lesson: lesson, user: user)
    }.to raise_error(LessonService::GenerateWordFamilies::Error)
  end

  it "enqueues a generation job for lessons with story SRT" do
    lesson = create(:lesson, :with_story)
    allow(Lesson::GenerateWordFamiliesJob).to receive(:perform_later).and_return(true)
    allow(NotificationService::Center).to receive(:notify)

    result = described_class.enqueue!(lesson: lesson, user: user)

    expect(result.operation_id).to be_present
    expect(Lesson::GenerateWordFamiliesJob).to have_received(:perform_later).with(
      hash_including(lesson_id: lesson.id, user_id: user.id)
    )
  end

  it "parses AI output, saves word families, and broadcasts the saved rows" do
    lesson = create(:lesson, :with_story)
    subtitle = lesson.story.subtitles.first
    allow(StorageService::Client).to receive(:download).with(subtitle.storage_key).and_return("1\n00:00:00,000 --> 00:00:01,000\nThe net is set.\n")
    allow(Ai::RunService).to receive(:execute_chat).and_return(
      {
        "choices" => [
          {
            "message" => {
              "content" => JSON.pretty_generate(
                [
                  { "pattern" => "..et", "words" => %w[net set pet get met] },
                  { "pattern" => "..at", "words" => %w[cat hat bat mat rat] },
                  { "pattern" => "..og", "words" => %w[dog fog] }
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
      operation_id: "lesson_word_families:#{lesson.id}:test"
    )
    allow(service).to receive(:latest_run_id).and_return(SecureRandom.uuid)
    service.process!

    families = lesson.reload.word_families.ordered
    expect(families.map { |row| [ row.pattern, row.words ] }).to eq(
      [
        [ "..et", %w[net set pet get] ],
        [ "..at", %w[cat hat bat mat] ]
      ]
    )
    expect(NotificationService::Center).to have_received(:notify).with(
      hash_including(
        operation_status: NotificationConstants::OperationStatus::COMPLETED,
        data: hash_including(
          type: NotificationConstants::NotificationType::LESSON_WORD_FAMILIES_GENERATED,
          word_families: [
            hash_including(id: families[0].id, pattern: "..et", words: %w[net set pet get], position: 0),
            hash_including(id: families[1].id, pattern: "..at", words: %w[cat hat bat mat], position: 1)
          ]
        )
      )
    )
  end
end
