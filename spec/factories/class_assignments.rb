FactoryBot.define do
  factory :class_assignment do
    school_class
    association :user

    before(:create) do |assignment|
      role = Iam::Role.find_or_create_by!(name: IamConstants::Role::TEACHER_ADMIN)
      Iam::UserRole.find_or_create_by!(user: assignment.user, role: role)
      CampusMembership.find_or_create_by!(
        campus: assignment.school_class.campus,
        user: assignment.user,
        kind: CampusConstants::MembershipKind::TEACHER_ADMIN
      )
    end
  end
end

