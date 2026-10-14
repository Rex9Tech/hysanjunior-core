require "rails_helper"

RSpec.describe "V1 Admin Class Assignments API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }
  let(:campus) { create(:campus) }
  let(:school_class) { create(:school_class, campus: campus) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "class_assignments", :read, :create, :delete)
  end

  def teacher_on_campus
    teacher = create(:user)
    role = Iam::Role.find_or_create_by!(name: IamConstants::Role::TEACHER_ADMIN)
    Iam::UserRole.find_or_create_by!(user: teacher, role: role)
    create(
      :campus_membership,
      campus: campus,
      user: teacher,
      kind: CampusConstants::MembershipKind::TEACHER_ADMIN
    )
    teacher
  end

  describe "POST /v1/admin/class_assignments" do
    it "assigns a campus teacher to a class" do
      teacher = teacher_on_campus

      post "/v1/admin/class_assignments", params: {
        class_assignment: {
          school_class_id: school_class.id,
          user_id: teacher.id
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "user_id")).to eq(teacher.id)
      expect(response_data.dig("attributes", "school_class_id")).to eq(school_class.id)
    end

    it "rejects a teacher who is not a campus member" do
      teacher = create(:user)
      role = Iam::Role.find_or_create_by!(name: IamConstants::Role::TEACHER_ADMIN)
      Iam::UserRole.find_or_create_by!(user: teacher, role: role)

      post "/v1/admin/class_assignments", params: {
        class_assignment: {
          school_class_id: school_class.id,
          user_id: teacher.id
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /v1/admin/class_assignments/:id" do
    it "removes a class assignment" do
      assignment = create(:class_assignment, school_class: school_class)

      delete "/v1/admin/class_assignments/#{assignment.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(assignment.reload.discarded?).to eq(true)
    end
  end
end
