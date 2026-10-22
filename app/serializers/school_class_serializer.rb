# app/serializers/school_class_serializer.rb

class SchoolClassSerializer < ApplicationSerializer
  attributes :id,
             :campus_id,
             :name,
             :level,
             :status,
             :discarded_at,
             :created_at,
             :updated_at

  attribute :campus do |school_class|
    CampusSerializer.record(school_class.campus)
  end

  attribute :students_count do |school_class|
    school_class.class_enrollments.active.size
  end

  attribute :teachers_count do |school_class|
    school_class.class_assignments.size
  end
end
