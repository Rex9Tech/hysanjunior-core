require "rails_helper"

RSpec.describe Campus, type: :model do
  it "lists active students through class enrollments" do
    campus = create(:campus)
    school_class = create(:school_class, campus: campus)
    enrollment = create(:class_enrollment, school_class: school_class)
    create(:class_enrollment, school_class: school_class, status: CampusConstants::EnrollmentStatus::LEFT)

    expect(campus.active_students).to contain_exactly(enrollment.user)
  end
end
