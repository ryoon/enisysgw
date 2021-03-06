# encoding: utf-8
class System::Admin::CustomGroupsController < Gw::Controller::Admin::Base
  include System::Controller::Scaffold
  layout "admin/template/admin"

  before_filter :set_groups_user, only: [:new, :create, :edit, :update]

  def initialize_scaffold
    @action = params[:action]
    id      = params[:parent] == '0' ? 1 : params[:parent]
    @parent = System::CustomGroup.new.find(:first,:conditions=>{:id=>id})
    Page.title = "カスタムグループ設定"
  end

  # === 初期値のグループ、ユーザー情報
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def set_groups_user
    # グループ
    @selected_parent_group_id_to_group = Site.user_group.id

    # ユーザー
    @selected_parent_group_id_to_user = Site.user_group.id
    @selectable_affiliated_users = System::UsersGroup.affiliated_users_to_select_option(@selected_parent_group_id_to_user)
  end

  def init_params
    @is_gw_admin = Gw.is_admin_admin?
    if params[:c1].present?
      #スケジューラー設定権限を持つユーザーかの情報
      @role_schedule = Gw.is_other_admin?('schedule_role')
      @is_gw_admin = @is_gw_admin || @role_schedule
    end
  end

  def init_index
    item = System::CustomGroup.new
    item.parent_id = @parent.id if @parent
    item.page  params[:page], params[:limit]
    item.order params[:sort], :sort_no
    cond = ''
    if @is_gw_admin != true
      user_groups = System::UsersGroup.where(user_id: Site.user.id)
      groups = ""
      user_groups.each do |ug|
        groups += ", " + ug.group_id.to_s if groups.present?
        groups = ug.group_id.to_s if groups.blank?
      end
=begin
      cond +=  " owner_uid = #{Site.user.id} " +
              " OR id in (" +
                " select custom_group_id from system_custom_group_roles where ( "+
                  " ( class_id = 2 AND system_custom_group_roles.group_id = #{Site.user_group.id} )" +
                  " OR ( system_custom_group_roles.class_id = 1 AND system_custom_group_roles.user_id = #{Site.user.id} )" +
                  " ) AND system_custom_group_roles.priv_name = 'admin' " +
              ") "
=end
      cond +=  " owner_uid = #{Site.user.id} " +
              " OR id in (" +
                " select custom_group_id from system_custom_group_roles where ( "+
                  " ( class_id = 2 AND system_custom_group_roles.group_id in(#{groups}) )" +
                  " OR ( system_custom_group_roles.class_id = 1 AND system_custom_group_roles.user_id = #{Site.user.id} )" +
                  " ) AND system_custom_group_roles.priv_name = 'admin' " +
              ") "
    end
    if params[:keyword].present? && params[:reset].blank?
      @keyword = params[:keyword]
      cond += " AND " if !cond.blank?
      cond += " name like '%#{@keyword}%' "
    end
    @items = item.find(:all, :conditions=>cond, :order=>'sort_prefix, sort_no' )
  end

  def index
    init_params
    init_index
    _index @items
  end

  def show
    init_params
    @item = System::CustomGroup.new.find(params[:id])
    _show @item
  end

  def new
    init_params
    #@is_gw_admin = Gw.is_admin_admin?
    @item = System::CustomGroup.new({
        :state        =>  'enabled',
    })
    @users = []

    base_users_json = []
    base_users_json << Site.user.to_json_option if @selectable_affiliated_users.map(&:id).include?(Site.user.id)
    base_users_json = base_users_json.to_json

    @admin_users_json = base_users_json
    @edit_users_json = base_users_json
    @read_users_json = base_users_json
  end

  def create
    init_params
    @item = System::CustomGroup.new
    if @item.save_with_rels params, :create
      flash_notice 'カスタムグループの作成', true
      if @is_gw_admin
        redirect_to '/system/custom_groups?c1=1'
      else
        redirect_to '/system/custom_groups'
      end
    else
      users = System::CustomGroup.get_error_users(params)
      @users_json = users.to_json
      @users = ::JsonParser.new.parse(@users_json)
      respond_to do |format|
        format.html { render :action => "new" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def create_all_group
    return
  end

  def get_users
    @users = ::JsonParser.new.parse(params[:item]['schedule_users_json'])
    @users.each_with_index {|user, i|
      @users[i][3] = params["title_#{user[1]}"]
      @users[i][4] = params["icon_#{user[1]}"]
      @users[i][5] = params["sort_no_#{user[1]}"]
    }
    respond_to do |format|
      format.xml { render :layout => false}
    end
  end

  def edit
    init_params
    #@is_gw_admin = Gw.is_admin_admin?
    @item = System::CustomGroup.new.find(params[:id])
    init_edit(:edit)
  end

  def init_edit(mode)
    users = []
    @item.custom_group_role.each do |custom_group|
      if custom_group.priv_name == 'admin' && custom_group.class_id == 1 && !custom_group.user.blank?
        users.push [1, custom_group.user.id, custom_group.user.display_name]
      end
    end
    @admin_users_json = users.to_json

    groups = []
    @item.custom_group_role.each do |custom_group|
      if custom_group.priv_name == 'admin' && custom_group.class_id == 2 && !custom_group.group.blank?
        groups.push [2, custom_group.group.id, custom_group.group.ou_name]
      end
    end
    @admin_groups_json = groups.to_json

    users = []
    @item.custom_group_role.each do |custom_group|
      if custom_group.priv_name == 'edit' && custom_group.class_id == 1 && !custom_group.user.blank?
        users.push [1, custom_group.user.id, custom_group.user.display_name]
      end
    end
    @edit_users_json = users.to_json

    groups = []
    @item.custom_group_role.each do |custom_group|
      if custom_group.priv_name == 'edit' && custom_group.class_id == 2 && !custom_group.group.blank?
        groups.push [2, custom_group.group.id, custom_group.group.ou_name]
      end
    end
    @edit_roles_json = groups.to_json

    groups = []
    @item.custom_group_role.each do |custom_group|
      if custom_group.priv_name == 'read' && custom_group.class_id == 2 && !custom_group.group.blank?
        if custom_group.group_id == 0
          groups.push [2, 0, '制限なし']
        else
          groups.push [2, custom_group.group.id, custom_group.group.ou_name]
        end
      end
    end
    @roles_json = groups.to_json

    users = []
    @item.custom_group_role.each do |custom_group|
      if custom_group.priv_name == 'read' && custom_group.class_id == 1 && !custom_group.user.blank?
        users.push [1, custom_group.user.id, custom_group.user.display_name]
      end
    end
    @read_users_json = users.to_json

    if mode == :edit
      users = []
      @item.user_custom_group.each do |user|
        next if user.user.blank?
        users.push [1, user.user.id, user.user.display_name_only , user.title, user.icon, user.sort_no]
      end
      users = users.sort{|a,b|
        a[5] <=> b[5]
      }
      @users_json = users.to_json
      @users = ::JsonParser.new.parse(@users_json)
    else
      # エラー発生時、ユーザーの情報を保持する
      users = System::CustomGroup.get_error_users(params)
      @users_json = users.to_json
      @users = ::JsonParser.new.parse(@users_json)
    end
  end

  def edit_users

  end

  def update
    init_params
    @item = System::CustomGroup.find(params[:id])
    if @item.save_with_rels params, :update
      flash_notice 'カスタムグループの編集', true
      if @is_gw_admin
        redirect_to '/system/custom_groups?c1=1'
      else
        redirect_to '/system/custom_groups'
      end
    else
      init_edit(:update)
      respond_to do |format|
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def sort_update
    init_params
    
    @item = System::CustomGroup.new
    unless params[:item].blank?
      params[:item].each{|key,value|
        if /^[0-9]+$/ =~ value
        else
          @item.errors.add :sort_no, "は数値を入力してください。"
          break
        end
      }
    end

    if @item.errors.size == 0
      unless params[:item].blank?
       params[:item].each{|key,value|
         cgid = key.slice(8, key.length - 7 ) #sort_no_* > *
         item = System::CustomGroup.new.find(cgid)
         item.sort_no = value
         item.save
       }
     end
     flash_notice 'カスタムグループの並び順更新', true
      if @is_gw_admin
        redirect_to '/system/custom_groups?c1=1'
      else
        redirect_to '/system/custom_groups'
      end
   else
      init_index
      respond_to do |format|
        format.html { render :action => "index" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
   end
  end


  def destroy
    init_params
    @item = System::CustomGroup.find(params[:id])
    if @item.destroy
      flash_notice 'カスタムグループの削除', true
      if @is_gw_admin
        redirect_to '/system/custom_groups?c1=1'
      else
        redirect_to '/system/custom_groups'
      end

    else
      respond_to do |format|
        format.html { render :action => "index" }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def synchro_all_group
    @is_gw_admin = Gw.is_admin_admin?
    @is_gw_admin = @is_gw_admin || @role_schedule if @role_schedule
    return authentication_error(403) unless @is_gw_admin == true

    customGroup_sort_no = 100
    systemGroups = System::Group.find(:all, :conditions => "state='enabled' and level_no = 3",
      :order=>'code, sort_no, name')


    systemGroups.each do |system_group|

      parent_group = System::Group.find(:first, :conditions=>"state='enabled' and id = #{system_group.parent_id}")

      customGroup = System::CustomGroup.find(:first, :conditions => "state='enabled' and name = '#{system_group.name}' and is_default = 1", :order => "sort_no")
      if customGroup.blank? && (!parent_group.blank? && parent_group.code != '600') && system_group.state == 'enabled'
        System::CustomGroup.create_new_custom_group(System::CustomGroup.new, system_group, customGroup_sort_no, :create)
        customGroup_sort_no = customGroup_sort_no + 10
      elsif !customGroup.blank? && system_group.state == 'enabled'
        System::CustomGroup.create_new_custom_group(customGroup, system_group, customGroup_sort_no, :update)
        customGroup_sort_no = customGroup_sort_no + 10
      elsif !customGroup.blank? && system_group.state == 'disabled'
        customGroup.state = 'disabled'
        customGroup.save(:validate=>false)
      end
    end

    customGroups = System::CustomGroup.find(:all, :conditions => "state='enabled' and is_default = 1", :order => "sort_no")

    customGroups.each do |custom_group|
      systemGroup = System::Group.find(:first, :conditions => "state='enabled' and name = '#{custom_group.name}'", :order => "sort_no")
      if systemGroup.blank?
        custom_group.state = 'disabled'
        custom_group.save(:validate=>false)
      end
    end
    flash_notice 'カスタムグループの同期', true
      if @is_gw_admin
        redirect_to '/system/custom_groups?c1=1'
      else
        redirect_to '/system/custom_groups'
      end
  end

  def user_add_sort_no
    @is_gw_admin = Gw.is_admin_admin?
    @is_gw_admin = @is_gw_admin || @role_schedule if @role_schedule
    return
    @is_gw_admin
    return authentication_error(403) unless @is_gw_admin == true

    systemGroups = System::Group.find(:all, :conditions => 'level_no = 3',
      :order=>'code, sort_no, name')

    systemGroups.each do |group|
      user_ids = Array.new
      _ka_user_code = "#{group.code}0"
      group.user_group.each do |user_group|
        user_ids << user_group.user_id if !user_group.blank? && user_group.user_code != _ka_user_code
      end

      users = Array.new
      unless user_ids.empty?
        user_ids_str = Gw.join(user_ids, ',')
        users = System::User.find(:all, :conditions=>"id in (#{user_ids_str}) and state = 'enabled'", :order => 'name')
      end

      sort_no = 5
      users.each do |user|
        user.sort_no = sort_no
        user.save(:validate=>false)
        sort_no += 5
      end
    end
  end
end
