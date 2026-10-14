# app/controllers/v1/admin/class_enrollments_controller.rb

class V1::Admin::ClassEnrollmentsController < V1::ApplicationController
  before_action :set_enrollment, only: %i[show update destroy]

  # GET /v1/admin/class_enrollments
  def index
    filters = filter_params
    records = ClassEnrollment.by_school_class(filters[:school_class_id])
                             .by_campus(filters[:campus_id])
                             .by_level(filters[:level])
                             .by_status(filters[:status])
    records = sort(records, columns: SortConstants::Columns::CLASS_ENROLLMENT)
    pagy, page_records = pagy(
      records.includes(:user, school_class: :campus, user: :parents),
      limit: filters[:limit]
    )

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::ENROLLMENT_FETCHED),
      **ClassEnrollmentSerializer.collection_pagy(page_records, pagy)
    )
  end

  # GET /v1/admin/class_enrollments/:id
  def show
    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::ENROLLMENT_FETCHED),
      data: ClassEnrollmentSerializer.record(@enrollment)
    )
  end

  # POST /v1/admin/class_enrollments
  def create
    enrollment = ClassEnrollment.create!(enrollment_params)

    render_json_response(
      status_code: 201,
      message: campus_message(MessageService::Campus::ENROLLMENT_CREATED),
      data: ClassEnrollmentSerializer.record(enrollment)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_failure(error)
  end

  # PUT/PATCH /v1/admin/class_enrollments/:id
  def update
    @enrollment.update!(enrollment_update_params)

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::ENROLLMENT_UPDATED),
      data: ClassEnrollmentSerializer.record(@enrollment)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_failure(error)
  end

  # DELETE /v1/admin/class_enrollments/:id
  def destroy
    @enrollment.discard

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::ENROLLMENT_DISCARDED)
    )
  end

  private

  def set_enrollment
    @enrollment = ClassEnrollment.kept.includes(:user, school_class: :campus, user: :parents).find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::ENROLLMENT_NOT_FOUND),
      error: campus_message(MessageService::Campus::ENROLLMENT_NOT_FOUND)
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
      :school_class_id, :campus_id, :level, :status,
      :limit, :page, :sort_by, :sort_order
    )
  end

  def enrollment_params
    permitted = params.require(:class_enrollment).permit(:school_class_id, :user_id, :status)
    permitted[:status] = CampusConstants::EnrollmentStatus::ACTIVE if permitted[:status].blank?
    permitted
  end

  def enrollment_update_params
    params.require(:class_enrollment).permit(:school_class_id, :status)
  end

  def campus_message(key, **options)
    MessageService::Campus.t(key, **options)
  end

  def permission_resource_name
    IamConstants::Resource::CLASS_ENROLLMENTS
  end
end
