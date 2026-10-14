# app/services/lesson_service/generate_build_the_sentences.rb

module LessonService
  class GenerateBuildTheSentences
    class Error < StandardError; end

    Result = Struct.new(:lesson, :run_id, :operation_id, :job, keyword_init: true)

    class << self
      def enqueue!(lesson:, user:)
        new(lesson:, user:).enqueue!
      end

      def process!(lesson_id:, user_id:, operation_id:)
        new(
          lesson: Lesson.kept.find(lesson_id),
          user: User.find(user_id),
          operation_id: operation_id
        ).process!
      end
    end

    def initialize(lesson:, user:, operation_id: nil)
      @lesson = lesson
      @user = user
      @operation_id = operation_id
    end

    def enqueue!
      unless @lesson.story_ready?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_SRT_REQUIRED)
      end

      if vocab_list.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::VOCAB_REQUIRED)
      end

      operation_id = "#{NotificationConstants::OperationType::LESSON_BUILD_THE_SENTENCES}:#{@lesson.id}:#{SecureRandom.uuid}"
      job = Lesson::GenerateBuildTheSentencesJob.perform_later(
        lesson_id: @lesson.id,
        user_id: @user.id,
        operation_id: operation_id
      )

      NotificationService::Center.notify(
        user_id: @user.id,
        title: MessageService::Lesson.t(MessageService::Lesson::BUILD_THE_SENTENCES_QUEUED),
        message: MessageService::Lesson.t(MessageService::Lesson::BUILD_THE_SENTENCES_QUEUED),
        operation_id: operation_id,
        operation_type: NotificationConstants::OperationType::LESSON_BUILD_THE_SENTENCES,
        operation_status: NotificationConstants::OperationStatus::QUEUED,
        send_push: false,
        send_socket: true,
        send_email: false,
        data: {
          type: NotificationConstants::NotificationType::LESSON_BUILD_THE_SENTENCES_GENERATED,
          lesson_id: @lesson.id,
          operation_status: NotificationConstants::OperationStatus::QUEUED
        }
      )

      Result.new(lesson: @lesson, run_id: nil, operation_id: operation_id, job: job)
    end

    def process!
      srt_text = download_story_srt!
      vocabs = vocab_list
      if vocabs.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::VOCAB_REQUIRED)
      end

      result = Ai::RunService.execute_chat(
        user: @user,
        feature: AiConstants::RunFeature::BUILD_THE_SENTENCES,
        profile_key: AiConstants::ProfileKey::BUILD_THE_SENTENCES,
        messages: [
          {
            role: AiConstants::ChatRole::USER,
            content: <<~CONTENT.strip
              Vocabulary items (one sentence each, same order):
              #{vocabs.map.with_index(1) { |vocab, index| "#{index}. #{vocab}" }.join("\n")}

              Story subtitle transcript:
              #{srt_text}
            CONTENT
          }
        ],
        request_metadata: {
          AiConstants::RequestMetadata::ENDPOINT => "v1/admin/lessons/create_build_the_sentences",
          AiConstants::RequestMetadata::LESSON_ID => @lesson.id
        }
      )

      if result[:error].present?
        broadcast_failure!(result[:error], run_id: latest_run_id)
        return
      end

      build_the_sentences = parse_build_the_sentences!(result)
      persist_build_the_sentences!(build_the_sentences)
      run_id = latest_run_id
      broadcast_success!(build_the_sentences, run_id: run_id)
      build_the_sentences
    rescue StandardError => error
      broadcast_failure!(error.message, run_id: latest_run_id)
      raise
    end

    private

    def persist_build_the_sentences!(build_the_sentences)
      rows = build_the_sentences.map do |pair|
        { "vocab" => pair[:vocab], "sentence" => pair[:sentence] }
      end
      @lesson.update!(build_the_sentences: rows)
    end

    def vocab_list
      @lesson.vocabularies.ordered.map { |row| row.vocab.to_s.strip }.reject(&:blank?)
    end

    def download_story_srt!
      subtitle = @lesson.story&.subtitles&.first
      raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_SRT_REQUIRED) if subtitle.blank?

      content = StorageService::Client.download(subtitle.storage_key).to_s
      raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_SRT_REQUIRED) if content.blank?

      content
    end

    def parse_build_the_sentences!(result)
      content = result.dig("choices", 0, "message", "content").to_s
      parsed = JSON.parse(content)
      rows = if parsed.is_a?(Hash) && parsed["build_the_sentences"].is_a?(Array)
        parsed["build_the_sentences"]
      elsif parsed.is_a?(Array)
        parsed
      else
        raise Error, MessageService::Lesson.t(MessageService::Lesson::BUILD_THE_SENTENCES_INVALID_AI)
      end

      pairs = rows.map { |row| normalize_pair(row) }.compact
      if pairs.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::BUILD_THE_SENTENCES_INVALID_AI)
      end

      pairs
    rescue JSON::ParserError
      raise Error, MessageService::Lesson.t(MessageService::Lesson::BUILD_THE_SENTENCES_INVALID_AI)
    end

    def normalize_pair(row)
      data = row.is_a?(Hash) ? row.stringify_keys : {}
      vocab = data["vocab"].to_s.strip
      sentence = data["sentence"].to_s.strip
      return nil if vocab.blank? || sentence.blank?

      { vocab: vocab, sentence: sentence }
    end

    def latest_run_id
      Ai::Run.where(user_id: @user.id, feature: AiConstants::RunFeature::BUILD_THE_SENTENCES)
             .order(created_at: :desc)
             .limit(1)
             .pick(:id)
    end

    def broadcast_success!(build_the_sentences, run_id:)
      message = MessageService::Lesson.t(MessageService::Lesson::BUILD_THE_SENTENCES_GENERATED)
      NotificationService::Center.notify(
        user_id: @user.id,
        title: message,
        message: message,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::LESSON_BUILD_THE_SENTENCES,
        operation_status: NotificationConstants::OperationStatus::COMPLETED,
        send_push: false,
        send_socket: true,
        send_email: false,
        data: {
          type: NotificationConstants::NotificationType::LESSON_BUILD_THE_SENTENCES_GENERATED,
          lesson_id: @lesson.id,
          run_id: run_id,
          build_the_sentences: build_the_sentences
        }
      )
    end

    def broadcast_failure!(error_message, run_id:)
      message = MessageService::Lesson.t(MessageService::Lesson::BUILD_THE_SENTENCES_FAILED)
      NotificationService::Center.notify(
        user_id: @user.id,
        title: message,
        message: message,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::LESSON_BUILD_THE_SENTENCES,
        operation_status: NotificationConstants::OperationStatus::FAILED,
        send_push: false,
        send_socket: true,
        send_email: false,
        data: {
          type: NotificationConstants::NotificationType::LESSON_BUILD_THE_SENTENCES_FAILED,
          lesson_id: @lesson.id,
          run_id: run_id,
          error: error_message
        }
      )
    end
  end
end
