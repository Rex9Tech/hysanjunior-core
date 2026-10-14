FactoryBot.define do
  factory :class_enrollment do
    school_class
    association :user
    status { CampusConstants::EnrollmentStatus::ACTIVE }

    after(:build) do |enrollment|
      role = Iam::Role.find_or_create_by!(name: IamConstants::Role::STUDENT)
      Iam::UserRole.find_or_create_by!(user: enrollment.user, role: role)
    end
  end
end
