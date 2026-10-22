# frozen_string_literal: true

# app/constants/campus_constants.rb
module CampusConstants
  module Status
    ACTIVE   = "active".freeze
    INACTIVE = "inactive".freeze
    ALL      = [ ACTIVE, INACTIVE ].freeze
  end

  module Level
    MIN = 1
  end

  module MembershipKind
    TEACHER_ADMIN = "teacher_admin".freeze
    ALL           = [ TEACHER_ADMIN ].freeze
  end

  module EnrollmentStatus
    ACTIVE = "active".freeze
    LEFT   = "left".freeze
    ALL    = [ ACTIVE, LEFT ].freeze
  end

  module HomeworkActivity
    LISTEN_AND_TAP          = "listen_and_tap".freeze
    SPEAK_AND_RECORD        = "speak_and_record".freeze
    TRACE_AND_WRITE         = "trace_and_write".freeze
    BLEND_THE_SOUND         = "blend_the_sound".freeze
    SORT_THE_WORD_FAMILIES  = "sort_the_word_families".freeze
    READ_A_STORY            = "read_a_story".freeze
    SING_AND_CHANT          = "sing_and_chant".freeze
    PUT_THE_STORY_IN_ORDER  = "put_the_story_in_order".freeze
    BUILD_THE_SENTENCES     = "build_the_sentences".freeze
    MADE_GOOD_CHOICE        = "made_good_choice".freeze
    SORT_HEALTHY_CHOICES    = "sort_healthy_choices".freeze

    ALL = [
      LISTEN_AND_TAP,
      SPEAK_AND_RECORD,
      TRACE_AND_WRITE,
      BLEND_THE_SOUND,
      SORT_THE_WORD_FAMILIES,
      READ_A_STORY,
      SING_AND_CHANT,
      PUT_THE_STORY_IN_ORDER,
      BUILD_THE_SENTENCES,
      MADE_GOOD_CHOICE,
      SORT_HEALTHY_CHOICES
    ].freeze

    LABELS = {
      LISTEN_AND_TAP => "Listen And Tap",
      SPEAK_AND_RECORD => "Speak and Record",
      TRACE_AND_WRITE => "Trace and Write",
      BLEND_THE_SOUND => "Blend the sound",
      SORT_THE_WORD_FAMILIES => "Sort the word families",
      READ_A_STORY => "Read a Story",
      SING_AND_CHANT => "Sing and chant",
      PUT_THE_STORY_IN_ORDER => "Put the story in order",
      BUILD_THE_SENTENCES => "Build the sentences",
      MADE_GOOD_CHOICE => "Made good choice",
      SORT_HEALTHY_CHOICES => "Sort Healthy Choices"
    }.freeze
  end
end
