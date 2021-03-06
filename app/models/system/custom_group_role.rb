# encoding: utf-8
class System::CustomGroupRole < ActiveRecord::Base
  include System::Model::Base
  include System::Model::Base::Config

  self.primary_key = 'rid'

  belongs_to :custom_group,  :foreign_key => :custom_group_id,     :class_name => 'System::CustomGroup'
  belongs_to :group       ,  :foreign_key => :group_id       ,     :class_name => 'System::Group'
  belongs_to :user        ,  :foreign_key => :user_id        ,     :class_name => 'System::User'

  def editable?( cgid, gid, uid )
    user_groups = System::UsersGroup.where(user_id: Site.user.id)
    groups = ""
    user_groups.each do |ug|
      groups += ", " + ug.group_id.to_s if groups.present?
      groups = ug.group_id.to_s if groups.blank?
    end
    #ret = self.find(:all, :conditions=>"custom_group_id = #{cgid} and ( (class_id = 2 and group_id = #{gid}) or (class_id = 1 and user_id = #{uid}) ) and priv_name = 'edit' " )
    ret = self.find(:all, :conditions=>"custom_group_id = #{cgid} and ( (class_id = 2 and group_id in (#{groups})) or (class_id = 1 and user_id = #{uid}) ) and priv_name = 'edit' " )
    return ret.size > 0
  end

end
