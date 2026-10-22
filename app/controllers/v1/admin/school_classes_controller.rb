# app/controllers/v1/admin/school_classes_controller.rb

class V1::Admin::SchoolClassesController < V1::ApplicationController
  before_action :set_school_class, only: %i[show update destroy]
  before_action :set_school_class_including_discarded, only: :undiscard

  # GET /v1/admin/school_classes
  def index
    filters = filter_params
    discarded = filters[:discarded].to_s == "true"
    records = discarded ? SchoolClass.with_discarded.discarded : SchoolClass.kept
    records = records.by_campus(filters[:campus_id])
                     .by_level(filters[:level])
                     .by_status(filters[:status])
                     .search_term(filters[:search])
    records = if discarded
      sort(records, columns: SortConstants::Columns::SCHOOL_CLASS, default_column: :discarded_at)
    else
      sort(records, columns: SortConstants::Columns::SCHOOL_CLASS)
    end
    pagy, page_records = pagy(records.includes(:campus, :class_enrollments), limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::CLASS_FETCHED),
      **SchoolClassSerializer.collection_pagy(page_records, pagy)
    )
  end

  # GET /v1/admin/school_classes/:id
  def show
    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::CLASS_FETCHED),
      data: SchoolClassSerializer.record(@school_class)
    )
  end

  # POST /v1/admin/school_classes
  def create
    school_class = SchoolClass.create!(school_class_params)

    render_json_response(
      status_code: 201,
      message: campus_message(MessageService::Campus::CLASS_CREATED),
      data: SchoolClassSerializer.record(school_class)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_failure(error)
  end

  # PUT/PATCH /v1/admin/school_classes/:id
  def update
    @school_class.update!(school_class_params)

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::CLASS_UPDATED),
      data: SchoolClassSerializer.record(@school_class)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_failure(error)
  end

  # DELETE /v1/admin/school_classes/:id
  def destroy
    @school_class.discard

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::CLASS_DISCARDED)
    )
  end

  # POST /v1/admin/school_classes/:id/undiscard
  def undiscard
    @school_class.undiscard

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::CLASS_UNDISCARDED),
      data: SchoolClassSerializer.record(@school_class)
    )
  end

  private

  def set_school_class
    @school_class = SchoolClass.kept.includes(:campus, :class_enrollments).find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::CLASS_NOT_FOUND),
      error: campus_message(MessageService::Campus::CLASS_NOT_FOUND)
    )
  end

  def set_school_class_including_discarded
    @school_class = SchoolClass.with_discarded.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::CLASS_NOT_FOUND),
      error: campus_message(MessageService::Campus::CLASS_NOT_FOUND)
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
    params.permit(:campus_id, :level, :status, :search, :discarded, :limit, :page, :sort_by, :sort_order)
  end

  def school_class_params
    params.require(:school_class).permit(:campus_id, :name, :level, :status)
  end

  def campus_message(key, **options)
    MessageService::Campus.t(key, **options)
  end

  def permission_resource_name
    IamConstants::Resource::SCHOOL_CLASSES
  end
end
