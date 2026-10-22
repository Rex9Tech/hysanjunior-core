require "rails_helper"

RSpec.describe "V1 Admin Campus Memberships API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }
  let(:campus) { create(:campus) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "campus_memberships", :read, :create, :delete)
  end

  describe "GET /v1/admin/campus_memberships/:id" do
    it "returns a campus membership" do
      membership = create(:campus_membership, campus: campus)

      get "/v1/admin/campus_memberships/#{membership.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data["id"]).to eq(membership.id)
      expect(response_data.dig("attributes", "campus_id")).to eq(campus.id)
    end
  end

  describe "POST /v1/admin/campus_memberships" do
    it "attaches a teacher_admin to a campus" do
      teacher = create(:user)
      role = Iam::Role.find_or_create_by!(name: IamConstants::Role::TEACHER_ADMIN)
      Iam::UserRole.find_or_create_by!(user: teacher, role: role)

      post "/v1/admin/campus_memberships", params: {
        campus_membership: {
          campus_id: campus.id,
          user_id: teacher.id,
          kind: CampusConstants::MembershipKind::TEACHER_ADMIN
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "user_id")).to eq(teacher.id)
      expect(response_data.dig("attributes", "kind")).to eq("teacher_admin")
    end

    it "rejects users without teacher_admin role" do
      user = create(:user)

      post "/v1/admin/campus_memberships", params: {
        campus_membership: {
          campus_id: campus.id,
          user_id: user.id
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
