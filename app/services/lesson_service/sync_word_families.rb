# app/services/lesson_service/sync_word_families.rb

module LessonService
  class SyncWordFamilies
    class Error < StandardError; end

    class << self
      def call(lesson, items:)
        new(lesson, items:).call
      end
    end

    def initialize(lesson, items:)
      @lesson = lesson
      @items = Array(items).map { |item| normalize_item(item) }
    end

    def call
      kept_ids = []

      @items.each_with_index do |item, index|
        family = upsert_row!(item, position: index)
        kept_ids << family.id
      end

      @lesson.word_families.where.not(id: kept_ids).find_each(&:destroy!)
      @lesson.word_families.reload
      @lesson
    end

    private

    def normalize_item(item)
      {
        id: item[:id],
        pattern: item[:pattern],
        words: item[:words]
      }
    end

    def upsert_row!(item, position:)
      pattern = item[:pattern].to_s.strip
      if pattern.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::WORD_FAMILY_PATTERN_REQUIRED)
      end

      words = normalize_words(item[:words])
      attributes = {
        pattern: pattern,
        words: words,
        position: position
      }

      if item[:id].present?
        family = @lesson.word_families.find_by(id: item[:id])
        raise Error, MessageService::Lesson.t(MessageService::Lesson::WORD_FAMILY_NOT_FOUND) if family.blank?

        family.update!(attributes)
        family
      else
        @lesson.word_families.create!(attributes)
      end
    end

    def normalize_words(raw)
      Array(raw).map { |word| word.to_s.strip }.reject(&:blank?)
    end
  end
end
