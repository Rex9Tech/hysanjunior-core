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
      campuses.includes(:school_classes, :campus_memberships, :assets),
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
    campus = Campus.create!(campus_attributes)
    assign_image!(campus) if image_param_provided?

    render_json_response(
      status_code: 201,
      message: campus_message(MessageService::Campus::CREATED),
      data: CampusSerializer.record(campus.reload)
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    render_campus_failure(error)
  end

  # PUT/PATCH /v1/admin/campuses/:id
  def update
    @campus.update!(campus_attributes)
    assign_image!(@campus) if image_param_provided?

    render_json_response(
      status_code: 200,
      message: campus_message(MessageService::Campus::UPDATED),
      data: CampusSerializer.record(@campus.reload)
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
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
    @campus = Campus.kept.includes(:school_classes, :campus_memberships, :assets).find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::NOT_FOUND),
      error: campus_message(MessageService::Campus::NOT_FOUND)
    )
  end

  def set_campus_including_discarded
    @campus = Campus.with_discarded.includes(:assets).find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: campus_message(MessageService::Campus::NOT_FOUND),
      error: campus_message(MessageService::Campus::NOT_FOUND)
    )
  end

  def render_campus_failure(error)
    message = if error.is_a?(ActiveRecord::RecordInvalid)
      error.record.errors.full_messages.join(", ")
    else
      error.message
    end

    render_json_response(
      status_code: 422,
      message: campus_message(MessageService::Campus::INVALID),
      error: message
    )
  end

  def filter_params
    params.permit(:status, :search, :discarded, :limit, :page, :sort_by, :sort_order)
  end

  def student_filter_params
    params.permit(:level, :school_class_id, :limit, :page, :sort_by, :sort_order)
  end

  def campus_params
    params.require(:campus).permit(:name, :code, :phone, :location, :status, :image_asset_id)
  end

  def campus_attributes
    campus_params.except(:image_asset_id)
  end

  def image_param_provided?
    campus_params.key?(:image_asset_id)
  end

  def assign_image!(campus)
    image_asset_id = campus_params[:image_asset_id]

    if image_asset_id.present?
      asset = Asset.find(image_asset_id)
      old_images = campus.assets.where(type: AssetConstants::AssetType::THUMBNAIL).where.not(id: asset.id)
      Asset.purge_and_destroy_all!(old_images)
      asset.update!(assetable: campus, type: AssetConstants::AssetType::THUMBNAIL)
    else
      Asset.purge_and_destroy_all!(campus.assets.where(type: AssetConstants::AssetType::THUMBNAIL))
    end
  end

  def campus_message(key, **options)
    MessageService::Campus.t(key, **options)
  end

  def permission_resource_name
    IamConstants::Resource::CAMPUSES
  end
end
