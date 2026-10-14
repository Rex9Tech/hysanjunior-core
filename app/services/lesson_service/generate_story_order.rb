# app/services/lesson_service/generate_story_order.rb

module LessonService
  class GenerateStoryOrder
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

      operation_id = "#{NotificationConstants::OperationType::LESSON_STORY_ORDER}:#{@lesson.id}:#{SecureRandom.uuid}"
      job = Lesson::GenerateStoryOrderJob.perform_later(
        lesson_id: @lesson.id,
        user_id: @user.id,
        operation_id: operation_id
      )

      NotificationService::Center.notify(
        user_id: @user.id,
        title: MessageService::Lesson.t(MessageService::Lesson::STORY_ORDER_QUEUED),
        message: MessageService::Lesson.t(MessageService::Lesson::STORY_ORDER_QUEUED),
        operation_id: operation_id,
        operation_type: NotificationConstants::OperationType::LESSON_STORY_ORDER,
        operation_status: NotificationConstants::OperationStatus::QUEUED,
        send_push: false,
        send_socket: true,
        send_email: false,
        data: {
          type: NotificationConstants::NotificationType::LESSON_STORY_ORDER_GENERATED,
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
        feature: AiConstants::RunFeature::STORY_ORDER,
        profile_key: AiConstants::ProfileKey::STORY_ORDER,
        messages: [
          {
            role: AiConstants::ChatRole::USER,
            content: "Story subtitle transcript:\n\n#{srt_text}"
          }
        ],
        request_metadata: {
          AiConstants::RequestMetadata::ENDPOINT => "v1/admin/lessons/create_story_order",
          AiConstants::RequestMetadata::LESSON_ID => @lesson.id
        }
      )

      if result[:error].present?
        broadcast_failure!(result[:error], run_id: latest_run_id)
        return
      end

      story_order = parse_story_order!(result)
      persist_story_order!(story_order)
      run_id = latest_run_id
      broadcast_success!(story_order, run_id: run_id)
      story_order
    rescue StandardError => error
      broadcast_failure!(error.message, run_id: latest_run_id)
      raise
    end

    private

    def persist_story_order!(story_order)
      @lesson.update!(story_order: story_order)
    end

    def download_story_srt!
      subtitle = @lesson.story&.subtitles&.first
      raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_SRT_REQUIRED) if subtitle.blank?

      content = StorageService::Client.download(subtitle.storage_key).to_s
      raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_SRT_REQUIRED) if content.blank?

      content
    end

    def parse_story_order!(result)
      content = result.dig("choices", 0, "message", "content").to_s
      parsed = JSON.parse(content)
      rows = if parsed.is_a?(Hash) && parsed["story_order"].is_a?(Array)
        parsed["story_order"]
      elsif parsed.is_a?(Array)
        parsed
      else
        raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_ORDER_INVALID_AI)
      end

      story_order = rows.map { |line| line.to_s.strip }.reject(&:blank?)
      if story_order.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_ORDER_INVALID_AI)
      end

      story_order
    rescue JSON::ParserError
      raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_ORDER_INVALID_AI)
    end

    def latest_run_id
      Ai::Run.where(user_id: @user.id, feature: AiConstants::RunFeature::STORY_ORDER)
             .order(created_at: :desc)
             .limit(1)
             .pick(:id)
    end

    def broadcast_success!(story_order, run_id:)
      message = MessageService::Lesson.t(MessageService::Lesson::STORY_ORDER_GENERATED)
      NotificationService::Center.notify(
        user_id: @user.id,
        title: message,
        message: message,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::LESSON_STORY_ORDER,
        operation_status: NotificationConstants::OperationStatus::COMPLETED,
        send_push: false,
        send_socket: true,
        send_email: false,
        data: {
          type: NotificationConstants::NotificationType::LESSON_STORY_ORDER_GENERATED,
          lesson_id: @lesson.id,
          run_id: run_id,
          story_order: story_order
        }
      )
    end

    def broadcast_failure!(error_message, run_id:)
      message = MessageService::Lesson.t(MessageService::Lesson::STORY_ORDER_FAILED)
      NotificationService::Center.notify(
        user_id: @user.id,
        title: message,
        message: message,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::LESSON_STORY_ORDER,
        operation_status: NotificationConstants::OperationStatus::FAILED,
        send_push: false,
        send_socket: true,
        send_email: false,
        data: {
          type: NotificationConstants::NotificationType::LESSON_STORY_ORDER_FAILED,
          lesson_id: @lesson.id,
          run_id: run_id,
          error: error_message
        }
      )
    end
  end
end
