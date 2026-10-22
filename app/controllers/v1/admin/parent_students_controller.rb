# app/controllers/v1/admin/parent_students_controller.rb

class V1::Admin::ParentStudentsController < V1::ApplicationController
  before_action :set_link, only: :destroy

  # GET /v1/admin/parent_students
  def index
    filters = filter_params
    records = ParentStudent.by_parent(filters[:parent_id]).by_student(filters[:student_id])
    records = sort(records, columns: SortConstants::Columns::PARENT_STUDENT)
    pagy, page_records = pagy(records.includes(:parent, :student), limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::PARENT_LINK_FETCHED),
      **ParentStudentSerializer.collection_pagy(page_records, pagy)
    )
  end

  # POST /v1/admin/parent_students
  def create
    link = ParentStudent.create!(link_params)

    render_json_response(
      status_code: 201,
      message: campus_message(MessageService::Campus::PARENT_LINK_CREATED),
      data: ParentStudentSerializer.record(link)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_failure(error)
  end

  # DELETE /v1/admin/parent_students/:id
  def destroy
    @link.discard

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::PARENT_LINK_DISCARDED)
    )
  end

  private

  def set_link
    @link = ParentStudent.kept.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::PARENT_LINK_NOT_FOUND),
      error: campus_message(MessageService::Campus::PARENT_LINK_NOT_FOUND)
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
    params.permit(:parent_id, :student_id, :limit, :page, :sort_by, :sort_order)
  end

  def link_params
    params.require(:parent_student).permit(:parent_id, :student_id)
  end

  def campus_message(key, **options)
    MessageService::Campus.t(key, **options)
  end

  def permission_resource_name
    IamConstants::Resource::PARENT_STUDENTS
  end
end
