require "rails_helper"

RSpec.describe "V1 Admin Class Homeworks API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }
  let(:school_class) { create(:school_class) }
  let(:lesson) { create(:lesson) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, "class_homeworks", :read, :create, :update, :delete)
  end

  describe "POST /v1/admin/class_homeworks" do
    it "assigns homework to a class with ordered activities" do
      post "/v1/admin/class_homeworks", params: {
        class_homework: {
          school_class_id: school_class.id,
          lesson_id: lesson.id,
          activity_keys: [
            CampusConstants::HomeworkActivity::LISTEN_AND_TAP,
            CampusConstants::HomeworkActivity::READ_A_STORY
          ],
          play_song_at_first: true,
          play_story_at_first: false,
          title: "Week 1 practice"
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "lesson_id")).to eq(lesson.id)
      expect(response_data.dig("attributes", "activity_keys")).to eq([
        "listen_and_tap",
        "read_a_story"
      ])
      expect(response_data.dig("attributes", "play_song_at_first")).to eq(true)
      expect(response_data.dig("attributes", "activity_labels")).to eq([
        "Listen And Tap",
        "Read a Story"
      ])
    end

    it "allows assigning the same lesson again" do
      create(:class_homework, school_class: school_class, lesson: lesson)

      post "/v1/admin/class_homeworks", params: {
        class_homework: {
          school_class_id: school_class.id,
          lesson_id: lesson.id,
          activity_keys: [ CampusConstants::HomeworkActivity::SING_AND_CHANT ]
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(ClassHomework.where(school_class_id: school_class.id, lesson_id: lesson.id).count).to eq(2)
    end

    it "rejects unknown activity keys" do
      post "/v1/admin/class_homeworks", params: {
        class_homework: {
          school_class_id: school_class.id,
          lesson_id: lesson.id,
          activity_keys: [ "made_up_activity" ]
        }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /v1/admin/class_homeworks" do
    it "lists homework for a school class" do
      create(:class_homework, school_class: school_class, lesson: lesson)

      get "/v1/admin/class_homeworks",
          params: { school_class_id: school_class.id },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data).to be_an(Array)
      expect(response_data.size).to eq(1)
    end
  end

  describe "PATCH /v1/admin/class_homeworks/:id" do
    it "updates activity order and flags" do
      homework = create(:class_homework, school_class: school_class, lesson: lesson)

      patch "/v1/admin/class_homeworks/#{homework.id}", params: {
        class_homework: {
          activity_keys: [ CampusConstants::HomeworkActivity::TRACE_AND_WRITE ],
          play_story_at_first: true
        }
      }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "activity_keys")).to eq([ "trace_and_write" ])
      expect(response_data.dig("attributes", "play_story_at_first")).to eq(true)
    end
  end

  describe "DELETE /v1/admin/class_homeworks/:id" do
    it "discards homework" do
      homework = create(:class_homework, school_class: school_class, lesson: lesson)

      delete "/v1/admin/class_homeworks/#{homework.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(ClassHomework.find_by(id: homework.id)).to be_nil
      expect(ClassHomework.unscoped.find(homework.id).discarded_at).to be_present
    end
  end
end
