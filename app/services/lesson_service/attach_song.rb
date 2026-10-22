# app/services/lesson_service/attach_song.rb

module LessonService
  class AttachSong
    class Error < StandardError; end

    class << self
      def call(lesson, song_asset_id: nil, audio: nil, srt: nil, created_by: nil, clear: false)
        new(lesson, song_asset_id:, audio:, srt:, created_by:, clear:).call
      end
    end

    def initialize(lesson, song_asset_id:, audio:, srt:, created_by:, clear:)
      @lesson = lesson
      @song_asset_id = song_asset_id
      @audio = audio
      @srt = srt
      @created_by = created_by
      @clear = clear
    end

    def call
      validate_input_paths!

      if @clear && @song_asset_id.blank? && @audio.blank?
        detach_current_song!
        return @lesson
      end

      if @audio.present?
        attach_from_upload!
      elsif @song_asset_id.present?
        attach_existing!
      end

      @lesson
    end

    private

    def validate_input_paths!
      uploading = @audio.present? || @srt.present?
      picking = @song_asset_id.present?

      if picking && uploading
        raise Error, MessageService::Lesson.t(MessageService::Lesson::SONG_PATHS_CONFLICT)
      end

      if @audio.present? ^ @srt.present?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::AUDIO_AND_SRT_REQUIRED)
      end
    end

    def attach_existing!
      asset = Asset.kept.find_by(id: @song_asset_id)
      raise Error, MessageService::Lesson.t(MessageService::Lesson::SONG_NOT_FOUND) if asset.blank?

      unless audio_parent?(asset)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::SONG_MUST_BE_AUDIO)
      end

      unless asset.subtitles.exists?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::SONG_SRT_REQUIRED)
      end

      detach_current_song!(except_id: asset.id)
      asset.update!(assetable: @lesson)
    end

    def attach_from_upload!
      validate_upload_files!

      audio_result = upload_audio_file!
      srt_result = nil
      audio_asset = nil

      begin
        Asset.transaction do
          audio_asset = create_audio_asset!(audio_result)
          srt_result = upload_srt_file!(audio_asset)
          AssetService::Upload.create_subtitle!(
            parent_asset: audio_asset,
            result: srt_result,
            fallback_size: @srt.size,
            created_by_id: @created_by&.id
          )
          detach_current_song!(except_id: audio_asset.id)
        end
        AssetService::Upload.enqueue_media_processing_if_needed(audio_asset)
      rescue StandardError
        StorageService::Client.delete(audio_result[:storage_key]) if audio_result&.dig(:storage_key)
        StorageService::Client.delete(srt_result[:storage_key], resource_type: "raw") if srt_result&.dig(:storage_key)
        raise
      end
    end

    def validate_upload_files!
      unless AssetService::Upload.audio_file?(@audio)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::SONG_MUST_BE_AUDIO)
      end

      unless AssetService::Upload.srt_file?(@srt)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::SONG_SRT_REQUIRED)
      end

      unless AssetService::Upload.within_upload_limit?(@audio)
        limit = AssetService::Upload.upload_limit_mb(@audio)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::FILE_SIZE_EXCEEDED, limit: limit)
      end

      unless AssetService::Upload.within_upload_limit?(@srt)
        limit = AssetService::Upload.upload_limit_mb(@srt)
        raise Error, MessageService::Lesson.t(MessageService::Lesson::FILE_SIZE_EXCEEDED, limit: limit)
      end
    end

    def upload_audio_file!
      storage_key = AssetConstants::AssetName.for_admin(
        type: AssetConstants::AssetType::GENERAL,
        original_filename: AssetService::Upload.filename_for(@audio)
      )
      StorageService::Client.upload(
        @audio,
        storage_key: storage_key,
        resource_type: AssetService::Upload.determine_resource_type(@audio),
        metadata: {
          user_id: @created_by&.id.to_s,
          original_filename: AssetService::Upload.filename_for(@audio)
        }
      )
    end

    def create_audio_asset!(result)
      Asset.create!(
        name: result[:storage_key],
        title: AssetService::Upload.filename_for(@audio),
        url: result[:url],
        type: AssetConstants::AssetType::GENERAL,
        format: AssetConstants::AssetFormat::AUDIO,
        size_bytes: result[:bytes] || @audio.size,
        source: AssetConstants::AssetSource::UPLOAD,
        storage_key: result[:storage_key],
        extension: result[:format].presence || AssetService::Upload.extension_for(@audio),
        status: AssetService::Upload.processing_status_for(@audio),
        assetable: @lesson,
        created_by_id: @created_by&.id
      )
    end

    def upload_srt_file!(audio_asset)
      StorageService::Client.upload(
        @srt,
        storage_key: AssetConstants::AssetName.subtitle_for(audio_asset, version: SecureRandom.uuid),
        resource_type: "raw"
      )
    end

    def detach_current_song!(except_id: nil)
      scope = @lesson.assets.where(
        format: AssetConstants::AssetFormat::AUDIO,
        parent_asset_id: nil
      )
      scope = scope.where.not(id: except_id) if except_id.present?
      scope.find_each { |asset| asset.update!(assetable: nil) }
    end

    def audio_parent?(asset)
      asset.parent_asset_id.blank? && asset.format == AssetConstants::AssetFormat::AUDIO
    end
  end
end
