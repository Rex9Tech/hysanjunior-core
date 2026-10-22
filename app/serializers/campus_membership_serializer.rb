# app/serializers/campus_membership_serializer.rb

class CampusMembershipSerializer < ApplicationSerializer
  attributes :id,
             :campus_id,
             :user_id,
             :kind,
             :created_at,
             :updated_at

  attribute :user do |membership|
    {
      id: membership.user.id,
      name: membership.user.name,
      username: membership.user.username,
      email: membership.user.email
    }
  end

  attribute :campus do |membership|
    CampusSerializer.record(membership.campus)
  end
end
