# app/serializers/campus_serializer.rb

class CampusSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :code,
             :status,
             :discarded_at,
             :created_at,
             :updated_at

  attribute :school_classes_count do |campus|
    campus.school_classes.size
  end

  attribute :teachers_count do |campus|
    campus.campus_memberships.size
  end
end
