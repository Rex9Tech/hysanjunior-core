require "rails_helper"

RSpec.describe "V1 Admin Campuses API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "campuses", :read, :create, :update, :delete)
    grant_admin_permissions(admin, "class_enrollments", :read)
  end

  describe "GET /v1/admin/campuses" do
    it "returns paginated campuses" do
      create_list(:campus, 3)

      get "/v1/admin/campuses", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(2)
      expect(response_meta.dig("pagination", "total_count")).to eq(3)
    end
  end

  describe "POST /v1/admin/campuses" do
    it "creates a campus" do
      post "/v1/admin/campuses", params: {
        campus: { name: "Downtown", code: "DT1", status: CampusConstants::Status::ACTIVE }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "name")).to eq("Downtown")
      expect(response_data.dig("attributes", "code")).to eq("DT1")
    end
  end

  describe "GET /v1/admin/campuses/:id/students" do
    it "lists students enrolled in classes under the campus" do
      campus = create(:campus)
      school_class = create(:school_class, campus: campus, level: 1, name: "A")
      enrollment = create(:class_enrollment, school_class: school_class)
      other = create(:campus)
      other_class = create(:school_class, campus: other, level: 1, name: "A")
      create(:class_enrollment, school_class: other_class)

      get "/v1/admin/campuses/#{campus.id}/students", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "user_id")).to eq(enrollment.user_id)
    end
  end

  describe "DELETE /v1/admin/campuses/:id" do
    it "discards a campus" do
      campus = create(:campus)

      delete "/v1/admin/campuses/#{campus.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(campus.reload.discarded?).to eq(true)
    end
  end
end
