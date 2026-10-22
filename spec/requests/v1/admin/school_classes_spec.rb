require "rails_helper"

RSpec.describe "V1 Admin School Classes API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }
  let(:campus) { create(:campus) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "school_classes", :read, :create, :update, :delete)
  end

  describe "POST /v1/admin/school_classes" do
    it "creates a class under a campus with a level" do
      post "/v1/admin/school_classes", params: {
        school_class: {
          campus_id: campus.id,
          name: "A",
          level: 2,
          status: CampusConstants::Status::ACTIVE
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "name")).to eq("A")
      expect(response_data.dig("attributes", "level")).to eq(2)
      expect(response_data.dig("attributes", "campus_id")).to eq(campus.id)
    end
  end

  describe "GET /v1/admin/school_classes" do
    it "filters by campus and level" do
      create(:school_class, campus: campus, level: 1, name: "A")
      create(:school_class, campus: campus, level: 2, name: "B")
      other = create(:campus)
      create(:school_class, campus: other, level: 1, name: "A")

      get "/v1/admin/school_classes", params: { campus_id: campus.id, level: 1 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to eq(1)
      expect(response_data.first.dig("attributes", "name")).to eq("A")
      expect(response_data.first.dig("attributes", "level")).to eq(1)
    end
  end
end
