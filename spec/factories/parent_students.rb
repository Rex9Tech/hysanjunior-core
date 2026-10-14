FactoryBot.define do
  factory :parent_student do
    association :parent, factory: :user
    association :student, factory: :user

    after(:build) do |link|
      parent_role = Iam::Role.find_or_create_by!(name: IamConstants::Role::PARENT)
      student_role = Iam::Role.find_or_create_by!(name: IamConstants::Role::STUDENT)
      Iam::UserRole.find_or_create_by!(user: link.parent, role: parent_role)
      Iam::UserRole.find_or_create_by!(user: link.student, role: student_role)
    end
  end
end
