# app/services/lesson_service/sync_questions.rb

module LessonService
  class SyncQuestions
    class Error < StandardError; end

    class << self
      def call(lesson, items:, created_by: nil)
        new(lesson, items:, created_by:).call
      end
    end

    def initialize(lesson, items:, created_by:)
      @lesson = lesson
      @items = Array(items).map { |item| normalize_item(item) }
      @created_by = created_by
    end

    def call
      kept_ids = []

      @items.each_with_index do |item, index|
        question = upsert_question!(item, position: index)
        sync_options!(question, item[:options])
        kept_ids << question.id
      end

      @lesson.questions.where.not(id: kept_ids).find_each(&:destroy!)
      @lesson.questions.reload
      @lesson
    end

    private

    def normalize_item(item)
      data = item.to_h.deep_symbolize_keys
      {
        id: data[:id],
        title: data[:title],
        kind: data[:kind].presence || QuestionConstants::Kind::MULTIPLE_CHOICE,
        options: Array(data[:options]).map { |option| normalize_option(option) }
      }
    end

    def normalize_option(option)
      data = option.to_h.deep_symbolize_keys
      {
        id: data[:id],
        text: data[:text],
        correct: ActiveModel::Type::Boolean.new.cast(data[:correct]) == true,
        image_asset_id: data[:image_asset_id],
        image: data[:image]
      }
    end

    def upsert_question!(item, position:)
      title = item[:title].to_s.strip
      if title.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_TITLE_REQUIRED)
      end

      unless QuestionConstants::Kind::ALL.include?(item[:kind])
        raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_KIND_INVALID)
      end

      attributes = {
        title: title,
        kind: item[:kind],
        position: position
      }

      if item[:id].present?
        question = @lesson.questions.find_by(id: item[:id])
        raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_NOT_FOUND) if question.blank?

        question.update!(attributes)
        question
      else
        @lesson.questions.create!(attributes)
      end
    end

    def sync_options!(question, options)
      kept_ids = []

      options.each_with_index do |option_item, index|
        option = upsert_option!(question, option_item, position: index)
        attach_image!(option, option_item)
        kept_ids << option.id
      end

      if options.present? && options.none? { |option| option[:correct] }
        raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_CORRECT_REQUIRED)
      end

      question.options.where.not(id: kept_ids).find_each(&:destroy!)
      question.options.reload
    end

    def upsert_option!(question, item, position:)
      text = item[:text].to_s.strip
      if text.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_OPTION_TEXT_REQUIRED)
      end

      attributes = {
        text: text,
        correct: item[:correct],
        position: position
      }

      if item[:id].present?
        option = question.options.find_by(id: item[:id])
        raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_OPTION_NOT_FOUND) if option.blank?

        option.update!(attributes)
        option
      else
        question.options.create!(attributes)
      end
    end

    def attach_image!(option, item)
      image_asset_id = item[:image_asset_id].presence
      image_file = item[:image]

      if image_asset_id.present? && image_file.present?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_OPTION_IMAGE_PATHS_CONFLICT)
      end

      if image_file.present?
        attach_from_upload!(option, image_file)
      elsif image_asset_id.present?
        attach_existing!(option, image_asset_id)
      end
    end

    def attach_existing!(option, image_asset_id)
      asset = Asset.kept.find_by(id: image_asset_id)
      raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_OPTION_IMAGE_NOT_FOUND) if asset.blank?

      unless image_parent?(asset)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_OPTION_IMAGE_MUST_BE_IMAGE)
      end

      detach_current_image!(option, except_id: asset.id)
      asset.update!(assetable: option)
    end

    def attach_from_upload!(option, file)
      unless AssetService::Upload.image_file?(file)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::QUESTION_OPTION_IMAGE_MUST_BE_IMAGE)
      end

      unless AssetService::Upload.within_upload_limit?(file)
        limit = AssetService::Upload.upload_limit_mb(file)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::FILE_SIZE_EXCEEDED, limit: limit)
      end

      result = nil
      begin
        storage_key = AssetConstants::AssetName.for_admin(
          type: AssetConstants::AssetType::GENERAL,
          original_filename: AssetService::Upload.filename_for(file)
        )
        result = StorageService::Client.upload(
          file,
          storage_key: storage_key,
          resource_type: AssetService::Upload.determine_resource_type(file),
          metadata: {
            user_id: @created_by&.id.to_s,
            original_filename: AssetService::Upload.filename_for(file)
          }
        )

        Asset.transaction do
          image_asset = Asset.create!(
            name: result[:storage_key],
            title: AssetService::Upload.filename_for(file),
            url: result[:url],
            type: AssetConstants::AssetType::GENERAL,
            format: AssetConstants::AssetFormat::IMAGE,
            size_bytes: result[:bytes] || file.size,
            source: AssetConstants::AssetSource::UPLOAD,
            storage_key: result[:storage_key],
            extension: result[:format].presence || AssetService::Upload.extension_for(file),
            status: AssetService::Upload.processing_status_for(file),
            assetable: option,
            created_by_id: @created_by&.id
          )
          detach_current_image!(option, except_id: image_asset.id)
          AssetService::Upload.enqueue_media_processing_if_needed(image_asset)
        end
      rescue StandardError
        StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key)
        raise
      end
    end

    def detach_current_image!(option, except_id: nil)
      scope = option.assets.where(
        format: AssetConstants::AssetFormat::IMAGE,
        parent_asset_id: nil
      )
      scope = scope.where.not(id: except_id) if except_id.present?
      scope.find_each { |asset| asset.update!(assetable: nil) }
    end

    def image_parent?(asset)
      asset.parent_asset_id.blank? && asset.format == AssetConstants::AssetFormat::IMAGE
    end
  end
end
