class Need < ActiveRecord::Base
	resourcify
	extend Enumerize

	enumerize :need_stage, in: {:user_posted => 1, :admin_incoming => 2, :admin_in_progress => 3, :admin_completed => 4}

  	belongs_to :user_posted_by, :foreign_key => 'user_id_posted_by', :class_name => "User"
  	belongs_to :user_church_admin, :foreign_key => 'user_id_church_admin', :class_name => "User"

	validates :description, presence: true, length: { minimum: 2 }
	validates :title, presence: true
	validates :user_id_posted_by, presence: true
end
