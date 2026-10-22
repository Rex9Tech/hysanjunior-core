FactoryBot.define do
  factory :sort_health_choice do
    association :lesson
    sequence(:label) { |n| "Group #{n}" }
    sequence(:position) { |n| n }

    trait :ready do
      after(:create) do |choice|
        create(
          :vocabulary,
          lesson: choice.lesson,
          sort_health_choice: choice,
          vocab: "apple",
          position: 0
        )
      end
    end
  end
end
