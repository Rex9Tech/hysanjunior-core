# app/controllers/v1/admin/campus_memberships_controller.rb

class V1::Admin::CampusMembershipsController < V1::ApplicationController
  before_action :set_membership, only: %i[show destroy]

  # GET /v1/admin/campus_memberships
  def index
    filters = filter_params
    records = CampusMembership.by_campus(filters[:campus_id]).by_kind(filters[:kind])
    records = sort(records, columns: SortConstants::Columns::CAMPUS_MEMBERSHIP)
    pagy, page_records = pagy(records.includes(:user, :campus), limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::MEMBERSHIP_FETCHED),
      **CampusMembershipSerializer.collection_pagy(page_records, pagy)
    )
  end

  # GET /v1/admin/campus_memberships/:id
  def show
    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::MEMBERSHIP_FETCHED),
      data: CampusMembershipSerializer.record(@membership)
    )
  end

  # POST /v1/admin/campus_memberships
  def create
    membership = CampusMembership.create!(membership_params)

    render_json_response(
      status_code: 201,
      message: campus_message(MessageService::Campus::MEMBERSHIP_CREATED),
      data: CampusMembershipSerializer.record(membership)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_failure(error)
  end

  # DELETE /v1/admin/campus_memberships/:id
  def destroy
    @membership.discard

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::MEMBERSHIP_DISCARDED)
    )
  end

  private

  def set_membership
    @membership = CampusMembership.kept.includes(:user, :campus).find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::MEMBERSHIP_NOT_FOUND),
      error: campus_message(MessageService::Campus::MEMBERSHIP_NOT_FOUND)
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
    params.permit(:campus_id, :kind, :limit, :page, :sort_by, :sort_order)
  end

  def membership_params
    permitted = params.require(:campus_membership).permit(:campus_id, :user_id, :kind)
    permitted[:kind] = CampusConstants::MembershipKind::TEACHER_ADMIN if permitted[:kind].blank?
    permitted
  end

  def campus_message(key, **options)
    MessageService::Campus.t(key, **options)
  end

  def permission_resource_name
    IamConstants::Resource::CAMPUS_MEMBERSHIPS
  end
end
