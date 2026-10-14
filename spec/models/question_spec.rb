require "rails_helper"

RSpec.describe Question, type: :model do
  it "is ready with title, at least two options, and one or more correct options" do
    question = create(:question, :ready)

    expect(question.ready?).to be(true)
    expect(question.options.count(&:correct?)).to eq(1)
  end

  it "allows multiple correct options" do
    question = create(:question)
    create(:question_option, question: question, text: "A", correct: true, position: 0)
    create(:question_option, question: question, text: "B", correct: true, position: 1)

    expect(question.ready?).to be(true)
    expect(question.options.count(&:correct?)).to eq(2)
  end

  it "is not ready without a correct option" do
    question = create(:question)
    create(:question_option, question: question, text: "A", correct: false, position: 0)
    create(:question_option, question: question, text: "B", correct: false, position: 1)

    expect(question.ready?).to be(false)
  end

  it "is not ready with fewer than two options" do
    question = create(:question)
    create(:question_option, question: question, text: "A", correct: true, position: 0)

    expect(question.ready?).to be(false)
  end
end
