# app/serializers/class_enrollment_serializer.rb

class ClassEnrollmentSerializer < ApplicationSerializer
  attributes :id,
             :school_class_id,
             :user_id,
             :status,
             :created_at,
             :updated_at

  attribute :student do |enrollment|
    {
      id: enrollment.user.id,
      name: enrollment.user.name,
      username: enrollment.user.username,
      email: enrollment.user.email
    }
  end

  attribute :school_class do |enrollment|
    SchoolClassSerializer.record(enrollment.school_class)
  end

  attribute :parents do |enrollment|
    enrollment.user.parents.map do |parent|
      {
        id: parent.id,
        name: parent.name,
        username: parent.username,
        email: parent.email
      }
    end
  end
end
