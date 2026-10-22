# app/serializers/campus_serializer.rb

class CampusSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :code,
             :phone,
             :location,
             :status,
             :discarded_at,
             :created_at,
             :updated_at

  attribute :image_asset_id do |campus|
    campus.image_asset_id
  end

  attribute :image do |campus|
    asset = campus.image
    asset.present? ? AssetSerializer.record(asset) : nil
  end

  attribute :school_classes_count do |campus|
    campus.school_classes.size
  end

  attribute :teachers_count do |campus|
    campus.campus_memberships.size
  end
end
