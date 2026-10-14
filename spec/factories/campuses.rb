FactoryBot.define do
  factory :campus do
    sequence(:name) { |n| "Campus #{n}" }
    sequence(:code) { |n| "C#{n}" }
    status { CampusConstants::Status::ACTIVE }
  end
end
