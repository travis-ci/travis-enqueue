class Repository < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
  has_one    :key, class_name: :SslKey

  has_many :permissions
  has_many :users, :through => :permissions

  def slug
    @slug ||= [owner_name, name].join('/')
  end

  def managed_by_app?
    !!managed_by_installation_at
  end

  def installation
    @installation ||= Installation.where(owner_id: owner_id, owner_type: owner_type, removed_by_id: nil).first
  end

  def settings
    @settings ||= Repository::Settings.load(super, repository_id: id).tap do |s|
      s.on_save do
        self.settings = s.to_json
        self.save!
      end
    end
  end
end

require 'travis/scheduler/record/repository/settings'
