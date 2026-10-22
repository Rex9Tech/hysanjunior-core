# app/services/lesson_service/generate_word_families.rb

module LessonService
  class GenerateWordFamilies
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

      operation_id = "#{NotificationConstants::OperationType::LESSON_WORD_FAMILIES}:#{@lesson.id}:#{SecureRandom.uuid}"
      job = Lesson::GenerateWordFamiliesJob.perform_later(
        lesson_id: @lesson.id,
        user_id: @user.id,
        operation_id: operation_id
      )

      NotificationService::Center.notify(
        user_id: @user.id,
        title: MessageService::Lesson.t(MessageService::Lesson::WORD_FAMILIES_QUEUED),
        message: MessageService::Lesson.t(MessageService::Lesson::WORD_FAMILIES_QUEUED),
        operation_id: operation_id,
        operation_type: NotificationConstants::OperationType::LESSON_WORD_FAMILIES,
        operation_status: NotificationConstants::OperationStatus::QUEUED,
        send_push: false,
        send_socket: true,
        send_email: false,
        data: {
          type: NotificationConstants::NotificationType::LESSON_WORD_FAMILIES_GENERATED,
          lesson_id: @lesson.id,
          operation_status: NotificationConstants::OperationStatus::QUEUED
        }
      )

      Result.new(lesson: @lesson, run_id: nil, operation_id: operation_id, job: job)
    end

    def process!
      srt_text = download_story_srt!
      result = Ai::RunService.execute_chat(
        user: @user,
        feature: AiConstants::RunFeature::WORD_FAMILY,
        profile_key: AiConstants::ProfileKey::WORD_FAMILY,
        messages: [
          {
            role: AiConstants::ChatRole::USER,
            content: <<~CONTENT.strip
              Return exactly #{LessonConstants::WordFamily::FAMILY_COUNT} word families.
              Each family must include exactly #{LessonConstants::WordFamily::WORDS_PER_FAMILY} words.

              Story subtitle transcript:

              #{srt_text}
            CONTENT
          }
        ],
        request_metadata: {
          AiConstants::RequestMetadata::ENDPOINT => "v1/admin/lessons/create_word_families",
          AiConstants::RequestMetadata::LESSON_ID => @lesson.id
        }
      )

      if result[:error].present?
        broadcast_failure!(result[:error], run_id: latest_run_id)
        return
      end

      families = parse_families!(result)
      persist_families!(families)
      run_id = latest_run_id
      saved = saved_families
      broadcast_success!(saved, run_id: run_id)
      saved
    rescue StandardError => error
      broadcast_failure!(error.message, run_id: latest_run_id)
      raise
    end

    private

    def persist_families!(families)
      LessonService::SyncWordFamilies.call(@lesson, items: families)
    end

    def saved_families
      @lesson.word_families.ordered.map do |family|
        {
          id: family.id,
          pattern: family.pattern,
          words: family.words,
          position: family.position
        }
      end
    end

    def download_story_srt!
      subtitle = @lesson.story&.subtitles&.first
      raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_SRT_REQUIRED) if subtitle.blank?

      content = StorageService::Client.download(subtitle.storage_key).to_s
      raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_SRT_REQUIRED) if content.blank?

      content
    end

    def parse_families!(result)
      content = result.dig("choices", 0, "message", "content").to_s
      parsed = JSON.parse(content)
      rows = if parsed.is_a?(Hash) && parsed["word_families"].is_a?(Array)
        parsed["word_families"]
      elsif parsed.is_a?(Array)
        parsed
      else
        raise Error, MessageService::Lesson.t(MessageService::Lesson::WORD_FAMILIES_INVALID_AI)
      end

      families = rows.map { |row| normalize_family(row) }.compact
      if families.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::WORD_FAMILIES_INVALID_AI)
      end

      families.first(LessonConstants::WordFamily::FAMILY_COUNT)
    rescue JSON::ParserError
      raise Error, MessageService::Lesson.t(MessageService::Lesson::WORD_FAMILIES_INVALID_AI)
    end

    def normalize_family(row)
      data = row.is_a?(Hash) ? row.stringify_keys : {}
      pattern = data["pattern"].to_s.strip
      words = Array(data["words"]).map { |word| word.to_s.strip }.reject(&:blank?)
      return nil if pattern.blank? || words.blank?

      {
        pattern: pattern,
        words: words.first(LessonConstants::WordFamily::WORDS_PER_FAMILY)
      }
    end

    def latest_run_id
      Ai::Run.where(user_id: @user.id, feature: AiConstants::RunFeature::WORD_FAMILY)
             .order(created_at: :desc)
             .limit(1)
             .pick(:id)
    end

    def broadcast_success!(families, run_id:)
      message = MessageService::Lesson.t(MessageService::Lesson::WORD_FAMILIES_GENERATED)
      NotificationService::Center.notify(
        user_id: @user.id,
        title: message,
        message: message,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::LESSON_WORD_FAMILIES,
        operation_status: NotificationConstants::OperationStatus::COMPLETED,
        send_push: false,
        send_socket: true,
        send_email: false,
        data: {
          type: NotificationConstants::NotificationType::LESSON_WORD_FAMILIES_GENERATED,
          lesson_id: @lesson.id,
          run_id: run_id,
          word_families: families
        }
      )
    end

    def broadcast_failure!(error_message, run_id:)
      message = MessageService::Lesson.t(MessageService::Lesson::WORD_FAMILIES_FAILED)
      NotificationService::Center.notify(
        user_id: @user.id,
        title: message,
        message: message,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::LESSON_WORD_FAMILIES,
        operation_status: NotificationConstants::OperationStatus::FAILED,
        send_push: false,
        send_socket: true,
        send_email: false,
        data: {
          type: NotificationConstants::NotificationType::LESSON_WORD_FAMILIES_FAILED,
          lesson_id: @lesson.id,
          run_id: run_id,
          error: error_message
        }
      )
    end
  end
end
