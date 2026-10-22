FactoryBot.define do
  factory :question_option do
    association :question
    sequence(:text) { |n| "Option #{n}" }
    correct { false }
    sequence(:position) { |n| n }
  end
end
