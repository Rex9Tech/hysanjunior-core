# frozen_string_literal: true

class Lesson::GenerateStoryOrderJob < ApplicationJob
  queue_as :ai

  limits_concurrency(
    to: 1,
    key: ->(lesson_id:, **) { lesson_id },
    duration: 30.minutes
  )

  retry_on Ai::Providers::Error,
           wait: :polynomially_longer,
           attempts: 5

  discard_on ActiveRecord::RecordNotFound

  def perform(lesson_id:, user_id:, operation_id:)
    LessonService::GenerateStoryOrder.process!(
      lesson_id: lesson_id,
      user_id: user_id,
      operation_id: operation_id
    )
  end
end
