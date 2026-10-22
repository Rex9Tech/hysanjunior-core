FactoryBot.define do
  factory :vocabulary do
    association :lesson
    sequence(:vocab) { |n| "Vocab #{n}" }
    vowel_symbol { nil }
    sequence(:position) { |n| n }
  end
end
