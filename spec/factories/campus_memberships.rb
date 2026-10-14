FactoryBot.define do
  factory :campus_membership do
    campus
    association :user
    kind { CampusConstants::MembershipKind::TEACHER_ADMIN }

    after(:build) do |membership|
      role = Iam::Role.find_or_create_by!(name: IamConstants::Role::TEACHER_ADMIN)
      Iam::UserRole.find_or_create_by!(user: membership.user, role: role)
    end
  end
end
