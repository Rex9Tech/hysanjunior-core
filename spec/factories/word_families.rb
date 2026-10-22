FactoryBot.define do
  factory :word_family do
    association :lesson
    sequence(:pattern) { |n| "..e#{n}" }
    words { %w[net set pet] }
    sequence(:position) { |n| n }
  end
end
