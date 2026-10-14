# app/services/lesson_service/persist.rb

module LessonService
  class Persist
    class << self
      def call(
        lesson,
        attributes:,
        creating:,
        song: {},
        story: {},
        vocabularies: nil,
        word_families: nil,
        questions: nil,
        sort_health_choices: nil,
        created_by: nil
      )
        new(
          lesson,
          attributes:,
          creating:,
          song:,
          story:,
          vocabularies:,
          word_families:,
          questions:,
          sort_health_choices:,
          created_by:
        ).call
      end
    end

    def initialize(
      lesson,
      attributes:,
      creating:,
      song:,
      story:,
      vocabularies:,
      word_families:,
      questions:,
      sort_health_choices:,
      created_by:
    )
      @lesson = lesson
      @attributes = attributes.to_h.symbolize_keys
      @creating = creating
      @song = song.to_h.symbolize_keys
      @story = story.to_h.symbolize_keys
      @vocabularies = vocabularies
      @word_families = word_families
      @questions = questions
      @sort_health_choices = sort_health_choices
      @created_by = created_by
    end

    def call
      desired_status = @attributes[:status].presence
      desired_status = LessonConstants::Status::DRAFT if @creating && desired_status.blank?
      publishing = desired_status == LessonConstants::Status::PUBLISHED

      attrs = @attributes.except(:status)
      if attrs.key?(:story_order)
        attrs[:story_order] = normalize_story_order(attrs[:story_order])
      end
      if attrs.key?(:build_the_sentences)
        attrs[:build_the_sentences] = normalize_build_the_sentences(attrs[:build_the_sentences])
      end

      @lesson.assign_attributes(attrs)
      @lesson.status = if publishing
        LessonConstants::Status::DRAFT
      else
        desired_status.presence || @lesson.status.presence || LessonConstants::Status::DRAFT
      end
      @lesson.save!

      begin
        attach_song_if_needed!
        attach_story_if_needed!
        sync_vocabularies_if_needed!
        sync_word_families_if_needed!
        sync_questions_if_needed!
        sync_sort_health_choices_if_needed!
        @lesson.update!(status: LessonConstants::Status::PUBLISHED) if publishing
      rescue LessonService::AttachSong::Error,
             LessonService::AttachStory::Error,
             LessonService::SyncVocabularies::Error,
             LessonService::SyncWordFamilies::Error,
             LessonService::SyncQuestions::Error,
             LessonService::SyncSortHealthChoices::Error,
             ActiveRecord::RecordInvalid
        if @creating &&
           @lesson.persisted? &&
           @lesson.song.blank? &&
           @lesson.story.blank? &&
           @lesson.vocabularies.blank? &&
           @lesson.word_families.blank? &&
           @lesson.questions.blank? &&
           @lesson.sort_health_choices.blank?
          @lesson.destroy!
        end
        raise
      end

      @lesson.reload
    end

    private

    def attach_song_if_needed!
      song_asset_id = @song[:song_asset_id]
      audio = @song[:audio]
      srt = @song[:srt]
      clear = @song[:clear] == true

      return if song_asset_id.blank? && audio.blank? && srt.blank? && !clear

      LessonService::AttachSong.call(
        @lesson,
        song_asset_id: song_asset_id,
        audio: audio,
        srt: srt,
        created_by: @created_by,
        clear: clear
      )
    end

    def attach_story_if_needed!
      story_asset_id = @story[:story_asset_id]
      video = @story[:video]
      video_srt = @story[:video_srt]
      thumbnail_asset_id = @story[:thumbnail_asset_id]
      thumbnail = @story[:thumbnail]
      clear = @story[:clear] == true

      return if story_asset_id.blank? &&
                video.blank? &&
                video_srt.blank? &&
                thumbnail_asset_id.blank? &&
                thumbnail.blank? &&
                !clear

      LessonService::AttachStory.call(
        @lesson,
        story_asset_id: story_asset_id,
        video: video,
        video_srt: video_srt,
        thumbnail_asset_id: thumbnail_asset_id,
        thumbnail: thumbnail,
        created_by: @created_by,
        clear: clear
      )
    end

    def sync_vocabularies_if_needed!
      return if @vocabularies.nil?

      LessonService::SyncVocabularies.call(
        @lesson,
        items: @vocabularies,
        created_by: @created_by
      )
    end

    def sync_word_families_if_needed!
      return if @word_families.nil?

      LessonService::SyncWordFamilies.call(
        @lesson,
        items: @word_families
      )
    end

    def sync_questions_if_needed!
      return if @questions.nil?

      LessonService::SyncQuestions.call(
        @lesson,
        items: @questions,
        created_by: @created_by
      )
    end

    def sync_sort_health_choices_if_needed!
      return if @sort_health_choices.nil?

      LessonService::SyncSortHealthChoices.call(
        @lesson,
        items: @sort_health_choices,
        created_by: @created_by
      )
    end

    def normalize_story_order(value)
      Array(value).map { |line| line.to_s.strip }.reject(&:blank?)
    end

    def normalize_build_the_sentences(value)
      Array(value).filter_map do |row|
        data = row.is_a?(Hash) ? row.stringify_keys : {}
        vocab = data["vocab"].to_s.strip
        sentence = data["sentence"].to_s.strip
        next if vocab.blank? || sentence.blank?

        { "vocab" => vocab, "sentence" => sentence }
      end
    end
  end
end
