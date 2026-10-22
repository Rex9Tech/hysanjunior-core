# frozen_string_literal: true

# app/constants/lesson_constants.rb
module LessonConstants
  module Status
    DRAFT       = "draft".freeze
    PUBLISHED   = "published".freeze
    UNPUBLISHED = "unpublished".freeze
    ALL         = [ DRAFT, PUBLISHED, UNPUBLISHED ].freeze
  end

  module Level
    MIN = 1
  end

  module WordFamily
    FAMILY_COUNT = 2
    WORDS_PER_FAMILY = 4
  end
end
