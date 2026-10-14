# app/controllers/v1/admin/campuses_controller.rb

class V1::Admin::CampusesController < V1::ApplicationController
  before_action :set_campus, only: %i[show update destroy students]
  before_action :set_campus_including_discarded, only: :undiscard

  # GET /v1/admin/campuses
  def index
    filters = filter_params
    discarded = filters[:discarded].to_s == "true"
    campuses = discarded ? Campus.with_discarded.discarded : Campus.kept
    campuses = campuses.by_status(filters[:status]).search_term(filters[:search])
    campuses = if discarded
      sort(campuses, columns: SortConstants::Columns::CAMPUS, default_column: :discarded_at)
    else
      sort(campuses, columns: SortConstants::Columns::CAMPUS)
    end
    pagy, records = pagy(
      campuses.includes(:school_classes, :campus_memberships),
      limit: filters[:limit]
    )

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::FETCHED),
      **CampusSerializer.collection_pagy(records, pagy)
    )
  end

  # GET /v1/admin/campuses/:id
  def show
    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::FETCHED),
      data: CampusSerializer.record(@campus)
    )
  end

  # POST /v1/admin/campuses
  def create
    campus = Campus.create!(campus_params)

    render_json_response(
      status_code: 201,
      message: campus_message(MessageService::Campus::CREATED),
      data: CampusSerializer.record(campus)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_campus_failure(error)
  end

  # PUT/PATCH /v1/admin/campuses/:id
  def update
    @campus.update!(campus_params)

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::UPDATED),
      data: CampusSerializer.record(@campus)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_campus_failure(error)
  end

  # DELETE /v1/admin/campuses/:id
  def destroy
    @campus.discard

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::DISCARDED)
    )
  end

  # POST /v1/admin/campuses/:id/undiscard
  def undiscard
    @campus.undiscard

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::UNDISCARDED),
      data: CampusSerializer.record(@campus)
    )
  end

  # GET /v1/admin/campuses/:id/students
  def students
    filters = student_filter_params
    enrollments = ClassEnrollment.active
                                 .by_campus(@campus.id)
                                 .by_level(filters[:level])
                                 .by_school_class(filters[:school_class_id])
                                 .includes(:user, :school_class, user: :parents)
    enrollments = sort(enrollments, columns: SortConstants::Columns::CLASS_ENROLLMENT)
    pagy, records = pagy(enrollments, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::STUDENTS_FETCHED),
      **ClassEnrollmentSerializer.collection_pagy(records, pagy)
    )
  end

  private

  def set_campus
    @campus = Campus.kept.includes(:school_classes, :campus_memberships).find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::NOT_FOUND),
      error: campus_message(MessageService::Campus::NOT_FOUND)
    )
  end

  def set_campus_including_discarded
    @campus = Campus.with_discarded.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::NOT_FOUND),
      error: campus_message(MessageService::Campus::NOT_FOUND)
    )
  end

  def render_campus_failure(error)
    render_json_response(
      status_code: 422,
      message: campus_message(MessageService::Campus::INVALID),
      error: error.record.errors.full_messages.join(", ")
    )
  end

  def filter_params
    params.permit(:status, :search, :discarded, :limit, :page, :sort_by, :sort_order)
  end

  def student_filter_params
    params.permit(:level, :school_class_id, :limit, :page, :sort_by, :sort_order)
  end

  def campus_params
    params.require(:campus).permit(:name, :code, :status)
  end

  def campus_message(key, **options)
    MessageService::Campus.t(key, **options)
  end

  def permission_resource_name
    IamConstants::Resource::CAMPUSES
  end
end
