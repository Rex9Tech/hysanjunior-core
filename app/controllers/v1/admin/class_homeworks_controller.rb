# app/controllers/v1/admin/class_homeworks_controller.rb

class V1::Admin::ClassHomeworksController < V1::ApplicationController
  before_action :set_homework, only: %i[show update destroy]

  # GET /v1/admin/class_homeworks
  def index
    filters = filter_params
    records = ClassHomework.by_school_class(filters[:school_class_id])
                           .by_lesson(filters[:lesson_id])
                           .by_campus(filters[:campus_id])
    records = sort(records, columns: SortConstants::Columns::CLASS_HOMEWORK)
    pagy, page_records = pagy(
      records.includes(:lesson, :school_class),
      limit: filters[:limit]
    )

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::HOMEWORK_FETCHED),
      **ClassHomeworkSerializer.collection_pagy(page_records, pagy)
    )
  end

  # GET /v1/admin/class_homeworks/:id
  def show
    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::HOMEWORK_FETCHED),
      data: ClassHomeworkSerializer.record(@homework)
    )
  end

  # POST /v1/admin/class_homeworks
  def create
    homework = ClassHomework.create!(homework_params)

    render_json_response(
      status_code: 201,
      message: campus_message(MessageService::Campus::HOMEWORK_CREATED),
      data: ClassHomeworkSerializer.record(homework)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_failure(error)
  end

  # PUT/PATCH /v1/admin/class_homeworks/:id
  def update
    @homework.update!(homework_update_params)

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::HOMEWORK_UPDATED),
      data: ClassHomeworkSerializer.record(@homework)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_failure(error)
  end

  # DELETE /v1/admin/class_homeworks/:id
  def destroy
    @homework.discard

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::HOMEWORK_DISCARDED)
    )
  end

  private

  def set_homework
    @homework = ClassHomework.kept.includes(:lesson, :school_class).find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::HOMEWORK_NOT_FOUND),
      error: campus_message(MessageService::Campus::HOMEWORK_NOT_FOUND)
    )
  end

  def render_failure(error)
    render_json_response(
      status_code: 422,
      message: campus_message(MessageService::Campus::INVALID),
      error: error.record.errors.full_messages.join(", ")
    )
  end

  def filter_params
    params.permit(
      :school_class_id, :lesson_id, :campus_id,
      :limit, :page, :sort_by, :sort_order
    )
  end

  def homework_params
    params.require(:class_homework).permit(
      :school_class_id,
      :lesson_id,
      :play_song_at_first,
      :play_story_at_first,
      :title,
      :due_on,
      activity_keys: []
    )
  end

  def homework_update_params
    params.require(:class_homework).permit(
      :lesson_id,
      :play_song_at_first,
      :play_story_at_first,
      :title,
      :due_on,
      activity_keys: []
    )
  end

  def campus_message(key, **options)
    MessageService::Campus.t(key, **options)
  end

  def permission_resource_name
    IamConstants::Resource::CLASS_HOMEWORKS
  end
end
