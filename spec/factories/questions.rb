FactoryBot.define do
  factory :question do
    association :questionable, factory: :lesson
    kind { QuestionConstants::Kind::MULTIPLE_CHOICE }
    sequence(:title) { |n| "Question #{n}" }
    sequence(:position) { |n| n }

    trait :ready do
      after(:create) do |question|
        create(:question_option, question: question, text: "Cat", correct: true, position: 0)
        create(:question_option, question: question, text: "Dog", correct: false, position: 1)
      end
    end
  end
end
