# app/serializers/class_assignment_serializer.rb

class ClassAssignmentSerializer < ApplicationSerializer
  attributes :id,
             :school_class_id,
             :user_id,
             :created_at,
             :updated_at

  attribute :teacher do |assignment|
    {
      id: assignment.user.id,
      name: assignment.user.name,
      username: assignment.user.username,
      email: assignment.user.email
    }
  end

  attribute :school_class do |assignment|
    SchoolClassSerializer.record(assignment.school_class)
  end
end
