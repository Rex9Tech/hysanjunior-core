FactoryBot.define do
  factory :school_class do
    campus
    sequence(:name) { |n| "Class #{n}" }
    level { 1 }
    status { CampusConstants::Status::ACTIVE }
  end
end
