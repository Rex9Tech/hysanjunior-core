# app/services/lesson_service/attach_vocabulary_image.rb

module LessonService
  class AttachVocabularyImage
    class << self
      def call(vocabulary:, image_asset_id:, image:, created_by:, error_class:)
        new(
          vocabulary:,
          image_asset_id:,
          image:,
          created_by:,
          error_class:
        ).call
      end
    end

    def initialize(vocabulary:, image_asset_id:, image:, created_by:, error_class:)
      @vocabulary = vocabulary
      @image_asset_id = image_asset_id
      @image = image
      @created_by = created_by
      @error_class = error_class
    end

    def call
      if @image_asset_id.present? && @image.present?
        raise @error_class, MessageService::Lesson.t(MessageService::Lesson::VOCAB_IMAGE_PATHS_CONFLICT)
      end

      if @image.present?
        attach_from_upload!
      elsif @image_asset_id.present?
        attach_existing!
      end
    end

    private

    def attach_existing!
      asset = Asset.kept.find_by(id: @image_asset_id)
      raise @error_class, MessageService::Lesson.t(MessageService::Lesson::VOCAB_IMAGE_NOT_FOUND) if asset.blank?

      unless image_parent?(asset)
        raise @error_class, MessageService::Lesson.t(MessageService::Lesson::VOCAB_IMAGE_MUST_BE_IMAGE)
      end

      detach_current_image!(except_id: asset.id)
      asset.update!(assetable: @vocabulary)
    end

    def attach_from_upload!
      unless AssetService::Upload.image_file?(@image)
        raise @error_class, MessageService::Lesson.t(MessageService::Lesson::VOCAB_IMAGE_MUST_BE_IMAGE)
      end

      unless AssetService::Upload.within_upload_limit?(@image)
        limit = AssetService::Upload.upload_limit_mb(@image)
        raise @error_class, MessageService::Lesson.t(MessageService::Lesson::FILE_SIZE_EXCEEDED, limit: limit)
      end

      result = nil
      begin
        storage_key = AssetConstants::AssetName.for_admin(
          type: AssetConstants::AssetType::GENERAL,
          original_filename: AssetService::Upload.filename_for(@image)
        )
        result = StorageService::Client.upload(
          @image,
          storage_key: storage_key,
          resource_type: AssetService::Upload.determine_resource_type(@image),
          metadata: {
            user_id: @created_by&.id.to_s,
            original_filename: AssetService::Upload.filename_for(@image)
          }
        )

        Asset.transaction do
          image_asset = Asset.create!(
            name: result[:storage_key],
            title: AssetService::Upload.filename_for(@image),
            url: result[:url],
            type: AssetConstants::AssetType::GENERAL,
            format: AssetConstants::AssetFormat::IMAGE,
            size_bytes: result[:bytes] || @image.size,
            source: AssetConstants::AssetSource::UPLOAD,
            storage_key: result[:storage_key],
            extension: result[:format].presence || AssetService::Upload.extension_for(@image),
            status: AssetService::Upload.processing_status_for(@image),
            assetable: @vocabulary,
            created_by_id: @created_by&.id
          )
          detach_current_image!(except_id: image_asset.id)
          AssetService::Upload.enqueue_media_processing_if_needed(image_asset)
        end
      rescue StandardError
        StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key)
        raise
      end
    end

    def detach_current_image!(except_id: nil)
      scope = @vocabulary.assets.where(
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
