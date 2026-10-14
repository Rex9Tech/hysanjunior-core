# app/services/asset_service/upload.rb

module AssetService
  class Upload
    class << self
      def filename_for(file_or_name)
        file_or_name.respond_to?(:original_filename) ? file_or_name.original_filename.to_s : file_or_name.to_s
      end

      def extension_for(file_or_name)
        File.extname(filename_for(file_or_name)).delete(".").downcase
      end

      def determine_resource_type(file_or_name)
        AssetConstants::AssetFormat.storage_resource_type(extension_for(file_or_name))
      end

      def determine_asset_format(file_or_name)
        AssetConstants::AssetFormat.from_extension(extension_for(file_or_name))
      end

      def upload_limit_mb(file_or_name)
        AssetConstants::AssetFormat.upload_limit_mb(extension_for(file_or_name))
      end

      def within_upload_limit?(file)
        file.size <= upload_limit_mb(file).megabytes
      end

      def audio_file?(file)
        file.present? && determine_asset_format(file) == AssetConstants::AssetFormat::AUDIO
      end

      def video_file?(file)
        file.present? && determine_asset_format(file) == AssetConstants::AssetFormat::VIDEO
      end

      def image_file?(file)
        file.present? &&
          file.content_type.to_s.start_with?("image/") &&
          determine_asset_format(file) == AssetConstants::AssetFormat::IMAGE
      end

      def srt_file?(file)
        file.present? &&
          file.content_type.to_s.in?(MediaConstants::SUBTITLE_CONTENT_TYPES) &&
          AssetConstants::AssetFormat::SUBTITLE_EXTENSIONS.include?(extension_for(file))
      end

      def file_processable?(file)
        MediaConstants::Processing::ALL_EXTENSIONS.include?(extension_for(file))
      end

      def processing_status_for(file)
        if MediaConstants::MEDIA_CONTAINER_ENABLED && file_processable?(file)
          MediaConstants::Status::PENDING
        else
          MediaConstants::Status::READY
        end
      end

      def create_subtitle!(parent_asset:, result:, fallback_size:, created_by_id: nil)
        Asset.create!(
          name: result[:storage_key],
          url: result[:url],
          type: AssetConstants::AssetType::SUBTITLE,
          format: AssetConstants::AssetFormat::SUBTITLE,
          extension: MediaConstants::SUBTITLE_EXT_SRT,
          size_bytes: result[:bytes] || fallback_size,
          source: AssetConstants::AssetSource::UPLOAD,
          status: MediaConstants::Status::READY,
          storage_key: result[:storage_key],
          assetable: parent_asset.assetable,
          parent_asset: parent_asset,
          created_by_id: created_by_id
        )
      end

      def replace_thumbnail!(parent_asset:, result:, fallback_size:, status: MediaConstants::Status::READY, created_by_id: nil)
        previous_storage_key = nil
        thumbnail = Asset.transaction do
          existing = Asset.find_by(
            parent_asset_id: parent_asset.id,
            type: AssetConstants::AssetType::THUMBNAIL
          )
          previous_storage_key = existing&.storage_key
          attributes = {
            name: result[:storage_key],
            url: result[:url],
            type: AssetConstants::AssetType::THUMBNAIL,
            format: AssetConstants::AssetFormat::IMAGE,
            extension: result[:format].presence || MediaConstants::IMAGE_EXT_WEBP,
            size_bytes: result[:bytes] || fallback_size,
            source: AssetConstants::AssetSource::UPLOAD,
            status: status,
            storage_key: result[:storage_key],
            assetable: parent_asset.assetable,
            parent_asset: parent_asset,
            created_by_id: created_by_id
          }

          if existing
            existing.update!(attributes)
            existing
          else
            Asset.create!(attributes)
          end
        end

        delete_replaced_storage(previous_storage_key, thumbnail.storage_key, resource_type: "image")
        parent_asset.association(:thumbnail).reset
        thumbnail
      end

      def link_thumbnail!(parent_asset:, thumbnail_asset:, created_by_id: nil)
        unless thumbnail_asset.format == AssetConstants::AssetFormat::IMAGE
          raise ArgumentError, "thumbnail asset must be an image"
        end

        previous = parent_asset.thumbnail
        previous_storage_key = nil

        Asset.transaction do
          if previous.present? && previous.id != thumbnail_asset.id
            previous_storage_key = previous.storage_key
            previous.update!(assetable: nil, parent_asset_id: nil)
          end

          thumbnail_asset.update!(
            type: AssetConstants::AssetType::THUMBNAIL,
            format: AssetConstants::AssetFormat::IMAGE,
            assetable: parent_asset.assetable,
            parent_asset: parent_asset,
            created_by_id: thumbnail_asset.created_by_id.presence || created_by_id
          )
        end

        parent_asset.association(:thumbnail).reset
        thumbnail_asset
      end

      def delete_replaced_storage(previous_key, replacement_key, resource_type:)
        return if previous_key.blank? || previous_key == replacement_key

        StorageService::Client.delete(previous_key, resource_type: resource_type)
      rescue StandardError => error
        Rails.error.report(error)
        Rails.logger.error("[AssetService::Upload] Failed to delete replaced storage object #{previous_key}: #{error.message}")
      end

      def enqueue_media_processing_if_needed(asset, generate_thumbnail: true)
        return unless asset.status == MediaConstants::Status::PENDING

        if asset.image_convertible?
          Media::ConvertImageJob.perform_later(asset_id: asset.id)
        elsif asset.compressible_video?
          Media::CompressMediaJob.perform_later(asset_id: asset.id)
          if generate_thumbnail
            Media::GenerateVideoThumbnailJob.perform_later(asset_id: asset.id)
          end
        elsif asset.compressible_image?
          Media::CompressMediaJob.perform_later(asset_id: asset.id)
        elsif asset.compressible_audio?
          Media::CompressMediaJob.perform_later(asset_id: asset.id)
        end
      end

      def enqueue_thumbnail_generation_if_needed(asset)
        return unless asset.thumbnail_generatable?
        return if asset.thumbnail.present?

        Media::GenerateVideoThumbnailJob.perform_later(asset_id: asset.id)
      end
    end
  end
end
