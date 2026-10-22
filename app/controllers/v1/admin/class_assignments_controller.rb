# app/controllers/v1/admin/class_assignments_controller.rb

class V1::Admin::ClassAssignmentsController < V1::ApplicationController
  before_action :set_assignment, only: :destroy

  # GET /v1/admin/class_assignments
  def index
    filters = filter_params
    records = ClassAssignment.by_school_class(filters[:school_class_id])
                             .by_campus(filters[:campus_id])
                             .by_user(filters[:user_id])
    records = sort(records, columns: SortConstants::Columns::CLASS_ASSIGNMENT)
    pagy, page_records = pagy(records.includes(:user, :school_class), limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::ASSIGNMENT_FETCHED),
      **ClassAssignmentSerializer.collection_pagy(page_records, pagy)
    )
  end

  # POST /v1/admin/class_assignments
  def create
    assignment = ClassAssignment.create!(assignment_params)

    render_json_response(
      status_code: 201,
      message: campus_message(MessageService::Campus::ASSIGNMENT_CREATED),
      data: ClassAssignmentSerializer.record(assignment)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_failure(error)
  end

  # DELETE /v1/admin/class_assignments/:id
  def destroy
    @assignment.discard

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::ASSIGNMENT_DISCARDED)
    )
  end

  private

  def set_assignment
    @assignment = ClassAssignment.kept.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::ASSIGNMENT_NOT_FOUND),
      error: campus_message(MessageService::Campus::ASSIGNMENT_NOT_FOUND)
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
    params.permit(:school_class_id, :campus_id, :user_id, :limit, :page, :sort_by, :sort_order)
  end

  def assignment_params
    params.require(:class_assignment).permit(:school_class_id, :user_id)
  end

  def campus_message(key, **options)
    MessageService::Campus.t(key, **options)
  end

  def permission_resource_name
    IamConstants::Resource::CLASS_ASSIGNMENTS
  end
end
