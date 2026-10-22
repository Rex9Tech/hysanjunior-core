require "rails_helper"

RSpec.describe "V1 Admin Parent Students API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "parent_students", :read, :create, :delete)
  end

  describe "POST /v1/admin/parent_students" do
    it "links a parent to a student without campus membership" do
      parent = create(:user)
      student = create(:user)
      Iam::UserRole.find_or_create_by!(
        user: parent,
        role: Iam::Role.find_or_create_by!(name: IamConstants::Role::PARENT)
      )
      Iam::UserRole.find_or_create_by!(
        user: student,
        role: Iam::Role.find_or_create_by!(name: IamConstants::Role::STUDENT)
      )

      post "/v1/admin/parent_students", params: {
        parent_student: {
          parent_id: parent.id,
          student_id: student.id
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "parent_id")).to eq(parent.id)
      expect(response_data.dig("attributes", "student_id")).to eq(student.id)
      expect(CampusMembership.count).to eq(0)
    end
  end
end
