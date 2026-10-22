# app/controllers/v1/admin/lessons_controller.rb

class V1::Admin::LessonsController < V1::ApplicationController
  before_action :set_lesson, only: %i[
    show update destroy create_word_families create_story_order create_build_the_sentences
  ]
  before_action :set_lesson_including_discarded, only: :undiscard

  # GET /v1/admin/lessons
  def index
    filters = filter_params
    discarded = filters[:discarded].to_s == "true"
    lessons = discarded ? Lesson.with_discarded.discarded : Lesson.kept
    lessons = lessons.by_status(filters[:status])
                     .by_level(filters[:level])
                     .by_unit(filters[:unit])
                     .search_term(filters[:search])
    lessons = if discarded
      sort(lessons, columns: SortConstants::Columns::LESSON, default_column: :discarded_at)
    else
      sort(lessons, columns: SortConstants::Columns::LESSON)
    end
    pagy, records = pagy(
      lessons.includes(
        :word_families,
        vocabularies: :assets,
        questions: { options: :assets },
        sort_health_choices: { vocabularies: :assets },
        assets: [ :subtitles, :thumbnail ]
      ),
      limit: filters[:limit]
    )

    render_json_response(
      status_code: 200,
      message: lesson_message(MessageService::Lesson::FETCHED),
      **LessonSerializer.collection_pagy(records, pagy)
    )
  end

  # GET /v1/admin/lessons/:id
  def show
    render_json_response(
      status_code: 200,
      message: lesson_message(MessageService::Lesson::FETCHED),
      data: LessonSerializer.record(@lesson)
    )
  end

  # POST /v1/admin/lessons
  def create
    lesson = LessonService::Persist.call(
      Lesson.new,
      attributes: lesson_attribute_params,
      creating: true,
      song: song_attach_params,
      story: story_attach_params,
      vocabularies: vocabulary_items_param,
      word_families: word_family_items_param,
      questions: question_items_param,
      sort_health_choices: sort_health_choice_items_param,
      created_by: current_user
    )

    render_json_response(
      status_code: 201,
      message: lesson_message(MessageService::Lesson::CREATED),
      data: LessonSerializer.record(lesson)
    )
  rescue ActiveRecord::RecordInvalid,
         LessonService::AttachSong::Error,
         LessonService::AttachStory::Error,
         LessonService::SyncVocabularies::Error,
         LessonService::SyncWordFamilies::Error,
         LessonService::SyncQuestions::Error,
         LessonService::SyncSortHealthChoices::Error => error
    render_lesson_failure(error)
  end

  # PUT/PATCH /v1/admin/lessons/:id
  def update
    lesson = LessonService::Persist.call(
      @lesson,
      attributes: lesson_attribute_params,
      creating: false,
      song: song_attach_params,
      story: story_attach_params,
      vocabularies: vocabulary_items_param,
      word_families: word_family_items_param,
      questions: question_items_param,
      sort_health_choices: sort_health_choice_items_param,
      created_by: current_user
    )

    render_json_response(
      status_code: 200,
      message: lesson_message(MessageService::Lesson::UPDATED),
      data: LessonSerializer.record(lesson)
    )
  rescue ActiveRecord::RecordInvalid,
         LessonService::AttachSong::Error,
         LessonService::AttachStory::Error,
         LessonService::SyncVocabularies::Error,
         LessonService::SyncWordFamilies::Error,
         LessonService::SyncQuestions::Error,
         LessonService::SyncSortHealthChoices::Error => error
    render_lesson_failure(error)
  end

  # POST /v1/admin/lessons/:id/create_word_families
  def create_word_families
    result = LessonService::GenerateWordFamilies.enqueue!(
      lesson: @lesson,
      user: current_user
    )

    render_json_response(
      status_code: 202,
      message: lesson_message(MessageService::Lesson::WORD_FAMILIES_QUEUED),
      data: {
        lesson_id: @lesson.id,
        operation_id: result.operation_id
      }
    )
  rescue LessonService::GenerateWordFamilies::Error => error
    render_lesson_failure(error)
  end

  # POST /v1/admin/lessons/:id/create_story_order
  def create_story_order
    result = LessonService::GenerateStoryOrder.enqueue!(
      lesson: @lesson,
      user: current_user
    )

    render_json_response(
      status_code: 202,
      message: lesson_message(MessageService::Lesson::STORY_ORDER_QUEUED),
      data: {
        lesson_id: @lesson.id,
        operation_id: result.operation_id
      }
    )
  rescue LessonService::GenerateStoryOrder::Error => error
    render_lesson_failure(error)
  end

  # POST /v1/admin/lessons/:id/create_build_the_sentences
  def create_build_the_sentences
    result = LessonService::GenerateBuildTheSentences.enqueue!(
      lesson: @lesson,
      user: current_user
    )

    render_json_response(
      status_code: 202,
      message: lesson_message(MessageService::Lesson::BUILD_THE_SENTENCES_QUEUED),
      data: {
        lesson_id: @lesson.id,
        operation_id: result.operation_id
      }
    )
  rescue LessonService::GenerateBuildTheSentences::Error => error
    render_lesson_failure(error)
  end

  # DELETE /v1/admin/lessons/:id
  def destroy
    @lesson.discard

    render_json_response(
      status_code: 200,
      message: lesson_message(MessageService::Lesson::DISCARDED)
    )
  end

  # POST /v1/admin/lessons/:id/undiscard
  def undiscard
    @lesson.undiscard

    render_json_response(
      status_code: 200,
      message: lesson_message(MessageService::Lesson::UNDISCARDED),
      data: LessonSerializer.record(@lesson)
    )
  end

  private

  def set_lesson
    @lesson = Lesson.kept.includes(
      :word_families,
      vocabularies: :assets,
      questions: { options: :assets },
      sort_health_choices: { vocabularies: :assets },
      assets: [ :subtitles, :thumbnail ]
    ).find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: lesson_message(MessageService::Lesson::NOT_FOUND),
      error: lesson_message(MessageService::Lesson::NOT_FOUND)
    )
  end

  def set_lesson_including_discarded
    @lesson = Lesson.with_discarded.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: lesson_message(MessageService::Lesson::NOT_FOUND),
      error: lesson_message(MessageService::Lesson::NOT_FOUND)
    )
  end

  def render_lesson_failure(error)
    detail = if error.is_a?(ActiveRecord::RecordInvalid)
      error.record.errors.full_messages.join(", ")
    else
      error.message
    end

    render_json_response(
      status_code: 422,
      message: lesson_message(MessageService::Lesson::INVALID),
      error: detail
    )
  end

  def filter_params
    params.permit(:status, :level, :unit, :search, :discarded, :limit, :page, :sort_by, :sort_order)
  end

  def lesson_attribute_params
    params.require(:lesson).permit(
      :title,
      :level,
      :unit,
      :status,
      story_order: [],
      build_the_sentences: [ :vocab, :sentence ]
    )
  end

  def song_attach_params
    song_asset_id = nested_lesson_param(:song_asset_id)
    audio = media_file_params[:audio]
    srt = media_file_params[:srt]
    clear = nested_lesson_key_provided?(:song_asset_id) && song_asset_id.blank? && audio.blank? && srt.blank?

    {
      song_asset_id: song_asset_id,
      audio: audio,
      srt: srt,
      clear: clear
    }
  end

  def story_attach_params
    story_asset_id = nested_lesson_param(:story_asset_id)
    thumbnail_asset_id = nested_lesson_param(:thumbnail_asset_id)
    video = media_file_params[:video]
    video_srt = media_file_params[:video_srt]
    thumbnail = media_file_params[:thumbnail]
    clear = nested_lesson_key_provided?(:story_asset_id) &&
            story_asset_id.blank? &&
            video.blank? &&
            video_srt.blank?

    {
      story_asset_id: story_asset_id,
      video: video,
      video_srt: video_srt,
      thumbnail_asset_id: thumbnail_asset_id,
      thumbnail: thumbnail,
      clear: clear
    }
  end

  # nil = key omitted (leave unchanged); array = full sync (empty clears)
  def vocabulary_items_param
    return nil unless nested_lesson_key_provided?(:vocabularies)

    permitted = params.require(:lesson).permit(
      vocabularies: [ :id, :vocab, :vowel_symbol, :image_asset_id, :image ]
    )
    Array(permitted[:vocabularies])
  end

  def word_family_items_param
    return nil unless nested_lesson_key_provided?(:word_families)

    permitted = params.require(:lesson).permit(
      word_families: [ :id, :pattern, { words: [] } ]
    )
    Array(permitted[:word_families])
  end

  def question_items_param
    return nil unless nested_lesson_key_provided?(:questions)

    permitted = params.require(:lesson).permit(
      questions: [
        :id,
        :title,
        :kind,
        {
          options: [ :id, :text, :correct, :image_asset_id, :image ]
        }
      ]
    )
    Array(permitted[:questions])
  end

  def sort_health_choice_items_param
    return nil unless nested_lesson_key_provided?(:sort_health_choices)

    permitted = params.require(:lesson).permit(
      sort_health_choices: [
        :id,
        :label,
        {
          items: [ :id, :vocab, :image_asset_id, :image ]
        }
      ]
    )
    Array(permitted[:sort_health_choices])
  end

  def nested_lesson_param(key)
    return nil unless params[:lesson].present?

    params.require(:lesson).permit(key)[key]
  end

  def nested_lesson_key_provided?(key)
    params[:lesson].is_a?(ActionController::Parameters) && params[:lesson].key?(key)
  end

  def media_file_params
    params.permit(:audio, :srt, :video, :video_srt, :thumbnail)
  end

  def lesson_message(key, **options)
    MessageService::Lesson.t(key, **options)
  end

  def permission_resource_name
    IamConstants::Resource::LESSONS
  end
end
