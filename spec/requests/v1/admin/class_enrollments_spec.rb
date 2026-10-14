require "rails_helper"

RSpec.describe "V1 Admin Class Enrollments API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }
  let(:school_class) { create(:school_class) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "class_enrollments", :read, :create, :update, :delete)
  end

  describe "POST /v1/admin/class_enrollments" do
    it "enrolls a student into a class" do
      student = create(:user)
      role = Iam::Role.find_or_create_by!(name: IamConstants::Role::STUDENT)
      Iam::UserRole.find_or_create_by!(user: student, role: role)

      post "/v1/admin/class_enrollments", params: {
        class_enrollment: {
          school_class_id: school_class.id,
          user_id: student.id
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "user_id")).to eq(student.id)
      expect(response_data.dig("attributes", "status")).to eq("active")
    end

    it "rejects a second active enrollment for the same student" do
      enrollment = create(:class_enrollment)
      other_class = create(:school_class, campus: enrollment.school_class.campus, name: "B", level: 1)

      post "/v1/admin/class_enrollments", params: {
        class_enrollment: {
          school_class_id: other_class.id,
          user_id: enrollment.user_id
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
