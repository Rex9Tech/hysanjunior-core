# app/serializers/parent_student_serializer.rb

class ParentStudentSerializer < ApplicationSerializer
  attributes :id,
             :parent_id,
             :student_id,
             :created_at,
             :updated_at

  attribute :parent do |link|
    {
      id: link.parent.id,
      name: link.parent.name,
      username: link.parent.username,
      email: link.parent.email
    }
  end

  attribute :student do |link|
    {
      id: link.student.id,
      name: link.student.name,
      username: link.student.username,
      email: link.student.email
    }
  end
end
