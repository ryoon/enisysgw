# encoding: utf-8
class Gw::ScheduleRepeat < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content

  has_many :schedules, :foreign_key => :schedule_repeat_id, :class_name => 'Gw::Schedule', :dependent=>:destroy
  has_many :reminders, foreign_key: :item_id, class_name: "Gw::Reminder", conditions: ["category like ? and sub_category = ?", "schedule%", "schedule_repeat"], dependent: :destroy

  def self.save_with_rels_concerning_repeat(item, params, mode)
    raise "update/create 以外は未実装です" if %w(update create).index(mode.to_s).nil?
    validates_date_error_message = "という日時は、データが異常、もしくは日付が存在しません。日時の入力内容は、直近の正常な日時に自動修正されます。ご注意ください。"

    form_kind_id = params[:item][:form_kind_id]
    if form_kind_id == "0"
      params[:item][:inquire_to] = ""
      params[:item][:schedule_props_json] = "[]"
    end

    _props = JsonParser.new.parse(params[:item][:schedule_props_json])

    has_pm = 0; has_ot_ot = 0; ot_ot_ids = []
    _masters = {'other'=>Gw::PropOther}
    prop_details = []
    _props.each{|x|
      _x = x
      _genre, _id = x[0], x[1]
      _x.push _masters[_genre].find(:first, :conditions=>"id=#{_id}")
      prop_details.push _x
    }
    prop_details.each{|x|
      _genre, _id, _prop = x[0], x[1], x[3]
      if nz(_prop.extra_flag, 'other') == 'pm' || nz(_prop.extra_flag, 'other') == 'other'
        has_pm += 1
        if x[0] == 'other'
          has_ot_ot += 1
          ot_ot_ids.push _id
        end
      end
    }

#予約可能期間・時間用の条件作成
    users = JsonParser.new.parse(params[:item][:schedule_users_json])
    cnt = 0
    cond = ""
    if !users.blank?
      users.each do |u|
        cond.concat " user_id = #{u[1].to_i} " if cnt == 0
        cond.concat " or user_id=#{u[1].to_i}" if cnt != 0
        cnt=1
      end
    end
    group_id = System::UsersGroup.find(:all, :conditions => cond, :select => "group_id", :group => "group_id", :order => "group_id") if cond.present?
    cnt=0
    cond = "id in ( select prop_setting_id from gw_prop_admin_setting_roles where "
    if !_props.blank?
      _props.each do | prop|
        cond.concat " (type_id = #{prop[3].type_id} " if cnt == 0
        cond.concat " or type_id = #{prop[3].type_id}" if cnt != 0
        cnt=1
      end
      cond.concat " ) "
    end
    cnt=0
    if !group_id.blank?
      cond.concat " and ( " if !_props.blank?
      group_id.each do | g|
        cond.concat " gid = #{g.group_id} " if cnt == 0
        cond.concat " or gid=#{g.group_id}" if cnt != 0
        cnt=1
      end
      cond.concat " ) "
    end
    cond.concat " group by prop_setting_id order by prop_setting_id) "
#予約可能期間・時間用の条件作成終了

#予約可能時間の取得処理
    if users.present?
      if !_props.blank?
        @admin_set_hour = Gw::PropAdminSetting.find(:all, :conditions => cond, :order => "id", :select => "min(span_hour) as span_hour")
        @admin_set_hour.each do | admin_set|
          @span_hour = admin_set.span_hour
        end
        if !@span_hour.blank?
          @admin_set_t = (@span_hour*60)*60
        end
      end
    end
#予約可能時間の取得処理終了

    is_gw_admin = Gw.is_admin_admin?

    target = System::ScheduleRole.get_target_uids(Site.user.id) if !is_gw_admin
    cnt = 0
    if target.present?
      users.each do |user|
        target.each do |target|
          if user[1].to_i == target.target_uid && cnt == 0
            item.errors.add :schedule_users_add_buf, 'はスケジュール登録に権限が必要なユーザーを含んでいます。ユーザーを再指定してください。'
            cnt = 1
          end
        end
      end
    end

    if mode == :update
      cg = Gw::Model::Schedule.get_group(:gid => item.creator_gid)
    else
      if params[:item][:creator_uid].blank?
        cu = Site.user
      else
        cu = System::User.get(item[:creator_uid])
      end
      cg = cu.groups[0]
    end

    ouid = params[:item][:owner_uid]
    if ouid.blank?
      item.errors.add :owner_udisplayname, 'は空欄となっています。ユーザーを指定してください。'
      return false
    end

    prop_flg = false
    prop_flg = true if has_ot_ot > 0

    if form_kind_id == "0" || (prop_flg)
      params[:item][:to_go] = ""
      params[:item][:participant_nums_inner] = ""
      params[:item][:participant_nums_outer] = ""
      params[:item][:check_30_over] = ""
      params[:item][:admin_memo] = ""
    end

    if has_ot_ot > 0
      params[:item][:allday] = nil
    else
      if params[:item][:allday_radio_id].present?
        if params[:init][:repeat_mode] == "1"
          params[:item][:allday] = params[:item][:allday_radio_id]
        elsif params[:init][:repeat_mode] == "2"
          params[:item][:allday] = params[:item][:repeat_allday_radio_id]
        end
      end
    end

    if prop_flg
      params[:item][:allday] = nil
    end

    params[:item][:guide_state] = '0'
    params[:item][:guide_place_id] = nil
    params[:item][:guide_place] = nil
    params[:item][:guide_ed_at] = '0'

    par_item_base, par_item_repeat = Gw::Schedule.separate_repeat_params params

    other_rent_flg = true
    other_admin_flg = true

    if !is_gw_admin
      ot_ot_ids.each{|o_props_id|
        flg = Gw::PropOtherRole.is_edit?(o_props_id)
        #unless flg
        prop = Gw::PropOther.find(o_props_id)
        if !flg || (prop && prop.reserved_state == 0 || prop.delete_state == 1)
          #施設マスタ権限を持つユーザーかの情報
          schedule_prop_admin = Gw.is_other_admin?('schedule_prop_admin')
          other_rent_flg = false unless schedule_prop_admin
        end
        other_admin_flg =  Gw::PropOtherRole.is_admin?(o_props_id, cg.id) if other_admin_flg
      }
    end

    item.errors.add :"この施設","は照会のみ可能で予約は行えません。予約する場合は，施設の管理所属にお問い合わせください。" if !other_rent_flg

    err_num_st = item.errors.count
    case params[:init][:repeat_mode]
# 通常の場合の処理
    when "1"
      st_at, ed_at = par_item_base[:st_at], par_item_base[:ed_at]

      unless Gw.validates_datetime(st_at)
        item.errors.add :st_at, "の「#{st_at}」#{validates_date_error_message}"
      end
      unless Gw.validates_datetime(ed_at)
        item.errors.add :ed_at, "の「#{ed_at}」#{validates_date_error_message}"
      end

      if item.errors.count == err_num_st
        d_st_at, d_ed_at = Gw.get_parsed_date(st_at), Gw.get_parsed_date(ed_at)

        if !prop_flg
          item.errors.add :ed_at, 'は、開始日時以降の日時を入力してください。' if d_st_at > d_ed_at
        else
          item.errors.add :ed_at, 'は、開始日時より後の日時を入力してください。' if d_st_at >= d_ed_at
        end

        #予約可能時間（通常時）のチェック
        if !_props.blank? && !@span_hour.blank?
          item.errors.add :st_at, "から終了日時までの間隔は、#{@span_hour}時間まで許可されています。開始日時、終了日時の見直しを行ってください。" if (d_ed_at.to_time - d_st_at.to_time) > @admin_set_t
        end
        #予約可能時間（通常時）のチェック終了

        #item.errors.add :st_at, 'と終了時刻は一年以内でなければいけません' if  (d_ed_at.to_time - d_st_at.to_time) > 86400 * 365

        # 競合チェック
        if mode == :create
          cond_shar = ""
        else
          cond_shar = " and schedule_id <> '#{item.id}'"
        end
        cond_shar = cond_shar +
          " and ( (gw_schedules.st_at <= '#{st_at}' and gw_schedules.ed_at > '#{st_at}' )" +
          " or (gw_schedules.st_at < '#{ed_at}' and gw_schedules.ed_at >= '#{ed_at}' )" +
          " or ('#{st_at}' <= gw_schedules.st_at and gw_schedules.st_at < '#{ed_at}') )"

        other_item_save_flg = true
        competition_prop_other_ids = []
        ot_ot_ids.each do |o_props_id|
          other_items = Gw::Schedule.find(:all, :joins=>'inner join gw_schedule_props on gw_schedules.id = gw_schedule_props.schedule_id',
            :conditions=>"prop_id='#{o_props_id}'" + "and gw_schedules.delete_state = 0" + cond_shar)
          if other_items.length > 0
            other_item_save_flg = false
          end

          unless other_item_save_flg
            competition_prop_other_ids << o_props_id
          end
        end

        unless other_item_save_flg
          competition_prop_other_ids = competition_prop_other_ids.uniq
          competition_prop_other_names = []
          competition_prop_other_ids.each do |competition_prop_other_id|
            prop_other = Gw::PropOther.find_by_id(competition_prop_other_id)
            competition_prop_other_names << prop_other.name if prop_other.present?
          end
          competition_prop_other_names = Gw.join(competition_prop_other_names, '，')

          competition_str = I18n.t("rumi.schedule.error_message.prop_other_reservation_conflict_datetime")
          item.errors.add :st_at, "、#{competition_str}（重複した施設：#{competition_prop_other_names}）"
        end

      end

      if item.errors.count == err_num_st
        #item.errors.add :st_at, 'と終了日時は一年以内でなければいけません。' if (d_ed_at - d_st_at) > 86400 * 365
        dates = (d_st_at.to_date..d_ed_at.to_date).to_a
      end

      prop_ids = _props.map {|p| p[1] }
      if prop_ids.present?
        #施設マスタ権限を持つユーザーかの情報
        schedule_prop_admin = Gw.is_other_admin?('schedule_prop_admin')
        prop_admin = Gw.is_admin_admin? || schedule_prop_admin

        prop_other = Gw::PropOther.where(id: prop_ids)
        prop_no_auth_ids = ""
        prop_ids.each do |prop|
          unless Gw::PropOtherRole.is_admin?(prop) && Gw::PropOtherRole.is_edit?(prop)
            prop_no_auth_ids += "," + prop.to_s if prop_no_auth_ids.present?
            prop_no_auth_ids = prop.to_s if prop_no_auth_ids.blank?
          end
        end

        unless prop_admin || prop_no_auth_ids.blank?
          tmp = prop_other.where("d_load_st IS NULL OR d_load_st <= ?", st_at)
                          .where("d_load_ed IS NULL OR d_load_ed >= ?", ed_at)
          unavailable_props = prop_other.select {|p| !p.available?(ed_at) }
        else
          tmp = prop_other
        end

        if _props.count != tmp.count
          sql = <<SQL
(d_load_st IS NOT NULL AND d_load_st > ? OR
 d_load_ed IS NOT NULL AND d_load_ed < ?)
SQL
          reservation_props = Gw::PropOther.select(:name)
                                           .where(id: prop_ids)
                                           .where(sql, st_at, ed_at)
          reservation_prop_names = reservation_props.map(&:name).join(', ')
          item.errors.add :d_load_at, "の範囲外の施設は予約できません。（該当する施設：#{reservation_prop_names}）"
        end

        if unavailable_props.present?
          item.errors.add :limit_month, "より先の予約を行うことはできません。（該当する施設：#{unavailable_props.map(&:name).join(', ')}）"
        end
      end
# 通常の場合の処理終了

# 繰り返しありの場合の処理
    when "2"

      st_date, ed_date = par_item_repeat[:st_date_at], par_item_repeat[:ed_date_at]
      st_time, ed_time = par_item_repeat[:st_time_at], par_item_repeat[:ed_time_at]

      %w(st_date ed_date st_time ed_time).each do |fld|
        unless Gw.validates_datetime eval(fld)
          item.errors.add "repeat_#{fld}_at", "の「#{eval(fld)}」#{validates_date_error_message}"
        end
      end

      if item.errors.count == err_num_st
        d_st_date, d_ed_date = Gw.get_parsed_date(st_date), Gw.get_parsed_date(ed_date)
        d_st_time, d_ed_time = Gw.get_parsed_date(st_time), Gw.get_parsed_date(ed_time)
        item.errors.add :repeat_ed_date_at, 'は、開始日より後の日付を入力してください。' if d_st_date >= d_ed_date
        if !prop_flg
          item.errors.add :repeat_ed_time_at, 'は、開始時刻以降の時刻を入力してください。' if d_st_time > d_ed_time
        else
          item.errors.add :repeat_ed_time_at, 'は、開始時刻より後の時刻を入力してください。' if d_st_time >= d_ed_time
        end

      end

      if item.errors.count == err_num_st
        #item.errors.add :repeat_st_time_at, 'と終了時刻は一年以内でなければいけません。' if (d_ed_date.to_time - d_st_date.to_time) > 86400 * 365

        if par_item_repeat[:class_id].blank?
          item.errors.add :repeat_class_id, 'を入力してください。'
        elsif par_item_repeat[:class_id].to_s == "3" && par_item_repeat[:weekday_ids].blank?
          item.errors.add :repeat_weekday_ids, 'を入力してください。'
        else

          dates = (d_st_date.to_date..d_ed_date.to_date).to_a
          case par_item_repeat[:class_id].to_s
          when "2"
            dates = dates.select{|x| !%w(1 2 3 4 5).index(x.wday.to_s).nil?}
          when "3"
            dates = dates.select{|x| !par_item_repeat[:weekday_ids].split(':').index(x.wday.to_s).nil?}
          end

          rent_date = st_date
          competition_prop_other_ids = []

          prop_join = "inner join gw_schedule_props on gw_schedules.id = gw_schedule_props.schedule_id"

          dates.each {|rent_date|
            st_at = "#{rent_date} #{st_time}"
            ed_at = "#{rent_date} #{ed_time}"

            cond_results_shar = " and (extra_data is null or extra_data not like '%\"cancelled\":1%')" +
              " and (schedule_repeat_id <> '#{item.schedule_repeat_id}' or schedule_repeat_id is null)" +
              " and ( (gw_schedules.st_at <= '#{st_at}' and gw_schedules.ed_at > '#{st_at}' )" +
              " or (gw_schedules.st_at < '#{ed_at}' and gw_schedules.ed_at >= '#{ed_at}' )" +
              " or ('#{st_at}' <= gw_schedules.st_at and gw_schedules.st_at < '#{ed_at}') )"


            other_item_save_flg = true
            ot_ot_ids.each{|o_props_id|
              if other_item_save_flg
                other_items = Gw::Schedule.find(:all, :joins=>prop_join,
                  :conditions=>"prop_id='#{o_props_id}'" + "and gw_schedules.delete_state = 0" + cond_results_shar)
                if other_items.length > 0
                  other_item_save_flg = false
                end

                unless other_item_save_flg
                  competition_prop_other_ids << o_props_id
                end
              end
            }
          }

          if competition_prop_other_ids.present?
            competition_prop_other_ids = competition_prop_other_ids.uniq
            competition_prop_other_names = []
            competition_prop_other_ids.each do |competition_prop_other_id|
              prop_other = Gw::PropOther.find_by_id(competition_prop_other_id)
              competition_prop_other_names << prop_other.name if prop_other.present?
            end
            competition_prop_other_names = Gw.join(competition_prop_other_names, '，')

            competition_str = I18n.t("rumi.schedule.error_message.prop_other_reservation_conflict_date")
            item.errors.add :repeat_st_date_at, "、#{competition_str}（重複した施設：#{competition_prop_other_names}）"
          end
          #item.errors.add :repeat_st_date_at, "、終了日の間の期間、条件に当てはまる日は#{dates.length}日となります。繰り返し回数は2～55回のみ許されます。開始日、終了日、規則などを見直し、再度登録してください。" if dates.length < 2 || 55 < dates.leng

          #予約可能期間のチェック
          if users.present?
            if !_props.blank?
              @admin_set_span = Gw::PropAdminSetting.find(:all, :conditions => cond, :order => "id", :select => "min(span) as span")
              @admin_set_span.each do | admin_set|
                @repeat_max = admin_set.span
              end
              if !@repeat_max.blank?
                item.errors.add :repeat_st_date_at, "、終了日の間の期間、条件に当てはまる日は#{dates.length}日となります。繰り返し回数は#{@repeat_max}回まで許されます。開始日、終了日、規則などを見直し、再度登録してください。" if dates.length < 2 || @repeat_max < dates.length
              end
            end
          end  #予約可能期間のチェック終了
        end
      end

      prop_ids = _props.map {|p| p[1] }
      if prop_ids.present?
        #施設マスタ権限を持つユーザーかの情報
        schedule_prop_admin = Gw.is_other_admin?('schedule_prop_admin')
        prop_admin = Gw.is_admin_admin? || schedule_prop_admin

        prop_other = Gw::PropOther.where(id: prop_ids)
        prop_no_auth_ids = ""
        prop_ids.each do |prop|
          unless Gw::PropOtherRole.is_admin?(prop) && Gw::PropOtherRole.is_edit?(prop)
            prop_no_auth_ids += "," + prop.to_s if prop_no_auth_ids.present?
            prop_no_auth_ids = prop.to_s if prop_no_auth_ids.blank?
          end
        end

        st_at = "#{st_date} #{st_time}"
        ed_at = "#{ed_date} #{ed_time}"
        unless prop_admin || prop_no_auth_ids.blank?
          tmp = prop_other.where("d_load_st IS NULL OR d_load_st <= ?", st_at)
                          .where("d_load_ed IS NULL OR d_load_ed >= ?", ed_at)
          unavailable_props = prop_other.select {|p| !p.available?(ed_at) }
        else
          tmp = prop_other
        end

        if _props.count != tmp.count
          sql = <<SQL
(d_load_st IS NOT NULL AND d_load_st > ? OR
 d_load_ed IS NOT NULL AND d_load_ed < ?)
SQL
          reservation_props = Gw::PropOther.select(:name)
                                           .where(id: prop_ids)
                                           .where(sql, st_at, ed_at)
          reservation_prop_names = reservation_props.map(&:name).join(', ')
          item.errors.add :d_load_at, "の範囲外の施設は予約できません。（該当する施設：#{reservation_prop_names}）"
        end

        if unavailable_props.present?
          item.errors.add :limit_month, "より先の予約を行うことはできません。（該当する施設：#{unavailable_props.map(&:name).join(', ')}）"
        end
      end
    end
# 繰り返しありの場合の処理終了

    %w(title is_public).each{|x| item.errors.add x, 'を入力してください。' if par_item_base[x].blank?}

    item.attributes = par_item_base.reject{|k,v|!%w(schedule_users_json schedule_props_json schedule_users public_groups public_groups_json schedule_props st_at_noprop ed_at_noprop event_week event_month event_word allday_radio_id allday_radio_id repeat_allday_radio_id form_kind_id).index(k).nil?}
    par_item_repeat.delete :allday_radio_id
    return false if item.errors.count != 0

    cnt = 0

    case params[:init][:repeat_mode]
    when "1"
      Gw::Schedule.save_with_rels item, params[:item], mode, {:restrict_trans=>1, :repeat_mode => params[:init][:repeat_mode]}
    when "2"
      date_for_time = Time.local(2010,4,1)
      par_item_repeat[:st_time_at] = Gw.datetime_merge(date_for_time, d_st_time)
      par_item_repeat[:ed_time_at] = Gw.datetime_merge(date_for_time, d_ed_time)
      item_org = item
      begin
        item_next = nil
        transaction do
          case mode
          when :update
            schedule_repeat_id = item.repeat.id
            cnt == 0 ? item_repeat = Gw::ScheduleRepeat.find(:first, :conditions=>"id=#{schedule_repeat_id}") : item_repeat = Gw::ScheduleRepeat.new
            item_repeat.update_attributes!(par_item_repeat)
            if cnt == 0
              repeat_items = Gw::Schedule.new.find(:all, :conditions=>"schedule_repeat_id=#{schedule_repeat_id}")
              repeat_items.each { |repeat_item|
                if !repeat_item.is_actual?
                  repeat_item.destroy
                end
              }
            end
            dates.each {|d|
              item_dup = par_item_base.dup.merge({
                :st_at => Gw.datetime_merge(d, d_st_time),
                :ed_at => Gw.datetime_merge(d, d_ed_time),
                :schedule_repeat_id => item_repeat.id,
              })
              _item = Gw::Schedule.new
              ret_swr = Gw::Schedule.save_with_rels _item, item_dup, mode, {:restrict_trans=>1, :repeat_mode => params[:init][:repeat_mode]}
              _item.errors.each{|x| item.errors.add x[0], x[1]} if item != _item
              item_next = _item if item_next.nil?
              raise if !ret_swr
              item.id = _item.id
            }
          when :create
            item_repeat = Gw::ScheduleRepeat.new(par_item_repeat)
            item_repeat.save!

            dates.each {|d|
              item_dup = par_item_base.dup.merge({
                :st_at => Gw.datetime_merge(d, d_st_time),
                :ed_at => Gw.datetime_merge(d, d_ed_time),
                :schedule_repeat_id => item_repeat.id,
              })

              _item = item.id.nil? ? item : Gw::Schedule.new
              ret_swr = Gw::Schedule.save_with_rels _item, item_dup, mode, {:restrict_trans=>1, :repeat_mode => params[:init][:repeat_mode]}
              _item.errors.each{|x| item.errors.add x[0], x[1]} if item != _item
              raise Gw::ARTransError if !ret_swr
            }
          end
        end
      rescue => e

        case e.class.to_s
        when 'ActiveRecord::RecordInvalid', 'Gw::ARTransError'
          if item != item_org
            item_with_errors = item
            item = item_org
            item_with_errors.errors.each{|x| item.errors.add x[0], x[1]}
          end
        else
          raise e
        end
        return false
      end
    else
      raise Gw::ApplicationError, "指定がおかしいです(repeat_mode=#{params[:init][:repeat_mode]})"
    end

    return true
  end

  # === 繰り返し予約作成時の複製元スケジュールを取得するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Gw::Schedule
  def first_day_schedule
    schedules.where(delete_state: 0).order(:id).first
  end
end
