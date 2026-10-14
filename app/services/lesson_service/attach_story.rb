# app/services/lesson_service/attach_story.rb

module LessonService
  class AttachStory
    class Error < StandardError; end

    class << self
      def call(
        lesson,
        story_asset_id: nil,
        video: nil,
        video_srt: nil,
        thumbnail_asset_id: nil,
        thumbnail: nil,
        created_by: nil,
        clear: false
      )
        new(
          lesson,
          story_asset_id:,
          video:,
          video_srt:,
          thumbnail_asset_id:,
          thumbnail:,
          created_by:,
          clear:
        ).call
      end
    end

    def initialize(
      lesson,
      story_asset_id:,
      video:,
      video_srt:,
      thumbnail_asset_id:,
      thumbnail:,
      created_by:,
      clear:
    )
      @lesson = lesson
      @story_asset_id = story_asset_id
      @video = video
      @video_srt = video_srt
      @thumbnail_asset_id = thumbnail_asset_id
      @thumbnail = thumbnail
      @created_by = created_by
      @clear = clear
    end

    def call
      validate_input_paths!

      if @clear && @story_asset_id.blank? && @video.blank?
        detach_current_story!
        return @lesson
      end

      if @video.present?
        attach_from_upload!
      elsif @story_asset_id.present?
        attach_existing!
      elsif custom_thumbnail_requested?
        apply_thumbnail_to_existing_story!
      end

      @lesson
    end

    private

    def validate_input_paths!
      uploading = @video.present? || @video_srt.present?
      picking = @story_asset_id.present?

      if picking && uploading
        raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_PATHS_CONFLICT)
      end

      if @video.present? ^ @video_srt.present?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::VIDEO_AND_SRT_REQUIRED)
      end

      if @thumbnail_asset_id.present? && @thumbnail.present?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::THUMBNAIL_PATHS_CONFLICT)
      end

      if custom_thumbnail_requested? && @story_asset_id.blank? && @video.blank? && @lesson.story.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_REQUIRED_FOR_THUMBNAIL)
      end
    end

    def custom_thumbnail_requested?
      @thumbnail_asset_id.present? || @thumbnail.present?
    end

    def attach_existing!
      asset = Asset.kept.find_by(id: @story_asset_id)
      raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_NOT_FOUND) if asset.blank?

      unless video_parent?(asset)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_MUST_BE_VIDEO)
      end

      unless asset.subtitles.exists?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_SRT_REQUIRED)
      end

      detach_current_story!(except_id: asset.id)
      asset.update!(assetable: @lesson)
      apply_thumbnail!(asset)
    end

    def attach_from_upload!
      validate_upload_files!

      video_result = upload_video_file!
      srt_result = nil
      thumb_result = nil
      video_asset = nil

      begin
        Asset.transaction do
          video_asset = create_video_asset!(video_result)
          srt_result = upload_srt_file!(video_asset)
          AssetService::Upload.create_subtitle!(
            parent_asset: video_asset,
            result: srt_result,
            fallback_size: @video_srt.size,
            created_by_id: @created_by&.id
          )
          detach_current_story!(except_id: video_asset.id)

          if @thumbnail.present?
            thumb_result = upload_thumbnail_file!(video_asset)
            AssetService::Upload.replace_thumbnail!(
              parent_asset: video_asset,
              result: thumb_result,
              fallback_size: @thumbnail.size,
              status: AssetService::Upload.processing_status_for(@thumbnail),
              created_by_id: @created_by&.id
            )
          elsif @thumbnail_asset_id.present?
            link_picked_thumbnail!(video_asset)
          end
        end

        AssetService::Upload.enqueue_media_processing_if_needed(
          video_asset,
          generate_thumbnail: !custom_thumbnail_requested?
        )
        if @thumbnail.present?
          AssetService::Upload.enqueue_media_processing_if_needed(video_asset.thumbnail)
        end
      rescue StandardError
        StorageService::Client.delete(video_result[:storage_key]) if video_result&.dig(:storage_key)
        StorageService::Client.delete(srt_result[:storage_key], resource_type: "raw") if srt_result&.dig(:storage_key)
        StorageService::Client.delete(thumb_result[:storage_key]) if thumb_result&.dig(:storage_key)
        raise
      end
    end

    def apply_thumbnail_to_existing_story!
      story = @lesson.story
      raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_REQUIRED_FOR_THUMBNAIL) if story.blank?

      apply_thumbnail!(story)
    end

    def apply_thumbnail!(video_asset)
      if @thumbnail.present?
        validate_thumbnail_file!
        result = nil
        begin
          result = upload_thumbnail_file!(video_asset)
          thumbnail = AssetService::Upload.replace_thumbnail!(
            parent_asset: video_asset,
            result: result,
            fallback_size: @thumbnail.size,
            status: AssetService::Upload.processing_status_for(@thumbnail),
            created_by_id: @created_by&.id
          )
          AssetService::Upload.enqueue_media_processing_if_needed(thumbnail)
        rescue StandardError
          StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key)
          raise
        end
      elsif @thumbnail_asset_id.present?
        link_picked_thumbnail!(video_asset)
      else
        AssetService::Upload.enqueue_thumbnail_generation_if_needed(video_asset)
      end
    end

    def link_picked_thumbnail!(video_asset)
      thumb = Asset.kept.find_by(id: @thumbnail_asset_id)
      raise Error, MessageService::Lesson.t(MessageService::Lesson::THUMBNAIL_NOT_FOUND) if thumb.blank?

      unless thumb.format == AssetConstants::AssetFormat::IMAGE
        raise Error, MessageService::Lesson.t(MessageService::Lesson::THUMBNAIL_MUST_BE_IMAGE)
      end

      AssetService::Upload.link_thumbnail!(
        parent_asset: video_asset,
        thumbnail_asset: thumb,
        created_by_id: @created_by&.id
      )
    end

    def validate_upload_files!
      unless AssetService::Upload.video_file?(@video)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_MUST_BE_VIDEO)
      end

      unless AssetService::Upload.srt_file?(@video_srt)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::STORY_SRT_REQUIRED)
      end

      unless AssetService::Upload.within_upload_limit?(@video)
        limit = AssetService::Upload.upload_limit_mb(@video)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::FILE_SIZE_EXCEEDED, limit: limit)
      end

      unless AssetService::Upload.within_upload_limit?(@video_srt)
        limit = AssetService::Upload.upload_limit_mb(@video_srt)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::FILE_SIZE_EXCEEDED, limit: limit)
      end

      validate_thumbnail_file! if @thumbnail.present?
    end

    def validate_thumbnail_file!
      unless AssetService::Upload.image_file?(@thumbnail)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::THUMBNAIL_MUST_BE_IMAGE)
      end

      unless AssetService::Upload.within_upload_limit?(@thumbnail)
        limit = AssetService::Upload.upload_limit_mb(@thumbnail)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::FILE_SIZE_EXCEEDED, limit: limit)
      end
    end

    def upload_video_file!
      storage_key = AssetConstants::AssetName.for_admin(
        type: AssetConstants::AssetType::GENERAL,
        original_filename: AssetService::Upload.filename_for(@video)
      )
      StorageService::Client.upload(
        @video,
        storage_key: storage_key,
        resource_type: AssetService::Upload.determine_resource_type(@video),
        metadata: {
          user_id: @created_by&.id.to_s,
          original_filename: AssetService::Upload.filename_for(@video)
        }
      )
    end

    def create_video_asset!(result)
      Asset.create!(
        name: result[:storage_key],
        title: AssetService::Upload.filename_for(@video),
        url: result[:url],
        type: AssetConstants::AssetType::GENERAL,
        format: AssetConstants::AssetFormat::VIDEO,
        size_bytes: result[:bytes] || @video.size,
        source: AssetConstants::AssetSource::UPLOAD,
        storage_key: result[:storage_key],
        extension: result[:format].presence || AssetService::Upload.extension_for(@video),
        status: AssetService::Upload.processing_status_for(@video),
        assetable: @lesson,
        created_by_id: @created_by&.id
      )
    end

    def upload_srt_file!(video_asset)
      StorageService::Client.upload(
        @video_srt,
        storage_key: AssetConstants::AssetName.subtitle_for(video_asset, version: SecureRandom.uuid),
        resource_type: "raw"
      )
    end

    def upload_thumbnail_file!(video_asset)
      extension = AssetService::Upload.extension_for(@thumbnail)
      StorageService::Client.upload(
        @thumbnail,
        storage_key: AssetConstants::AssetName.thumbnail_for(
          video_asset,
          version: SecureRandom.uuid,
          extension: extension
        ),
        resource_type: "image"
      )
    end

    def detach_current_story!(except_id: nil)
      scope = @lesson.assets.where(
        format: AssetConstants::AssetFormat::VIDEO,
        parent_asset_id: nil
      )
      scope = scope.where.not(id: except_id) if except_id.present?
      scope.find_each { |asset| asset.update!(assetable: nil) }
    end

    def video_parent?(asset)
      asset.parent_asset_id.blank? && asset.format == AssetConstants::AssetFormat::VIDEO
    end
  end
end
