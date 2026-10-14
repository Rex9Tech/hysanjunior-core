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
end
