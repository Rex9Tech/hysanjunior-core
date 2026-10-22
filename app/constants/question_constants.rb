# frozen_string_literal: true

# app/constants/question_constants.rb
module QuestionConstants
  module Kind
    MULTIPLE_CHOICE = "multiple_choice".freeze

    ALL = [ MULTIPLE_CHOICE ].freeze
  end

  module Option
    MIN_COUNT = 2
  end
end
