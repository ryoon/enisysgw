# encoding: utf-8
module Gw::SchedulesHelper

  def show_schedule_edit_icon(d, options={})
    par_a = [%Q(s_date=#{(d).strftime("%Y%m%d")})]
    par_a.push "uid=#{options[:uid]}" if options[:uid].present?
    par_a.push "prop_id=#{options[:prop_id]}" if options[:prop_id].present?
    par_a.push "s_genre=#{options[:s_genre]}" if options[:s_genre].present?
    par_s = Gw.a_to_qs(par_a);
    return %Q(<a href="/gw/schedules/new#{par_s}"><img src="/_common/themes/gw/files/schedule/ic_add.gif" alt="edit" width="15" height="15" align="top" /></a>).html_safe
  end

  def create_month_class(week_add_day, date, holidays, params)
    class_str = %Q(scheduleData #{Gw.weekday_s(week_add_day, :mode => :eh, :no_weekday => 1, :holidays => holidays)})
    class_str.concat ' today' if (week_add_day) == Date.today
    class_str.concat ' selectDay' if (week_add_day) == nz(params[:s_date], Date.today.to_s).to_date
    return class_str
  end

  def create_month_class_noweek(week_add_day, date, holidays, params)
    class_str = %Q(scheduleData dayHeder #{Gw.weekday_s(week_add_day, :mode => :eh, :no_weekday => 1, :holidays => holidays)})
    class_str.concat ' today' if (week_add_day) == Date.today
    class_str.concat ' selectDay' if (week_add_day) == nz(params[:s_date], Date.today.to_s).to_date
    return class_str
  end

  def create_schedule_tooltip(schedule, is_ie, options = {})
    is_ie = Gw.ie?(request) unless is_ie
    title_category = Gw.yaml_to_array_for_select('gw_schedules_title_categories').to_a.rassoc(schedule.title_category_id.to_i) # 件名カテゴリ
    is_public = Gw.yaml_to_array_for_select('gw_schedules_public_states').to_a.rassoc(schedule.is_public.to_i) # 公開範囲
    if title_category.present?
      title = "件名：【#{title_category[0]}】 #{schedule.title}"
    else
      title = "件名：#{schedule.title}"
    end

    place = schedule.place.blank? ? "" :"場所： #{schedule.place}"
    memo = schedule.memo.blank? ? "" : is_ie ? "メモ： #{schedule.memo}" : "メモ： #{Gw.br(schedule.memo)}"
    inquire_to = schedule.inquire_to.blank? ? "" : "連絡先： #{schedule.inquire_to}"
    public = is_public.blank? ? nil : "公開範囲： #{is_public[0]}"

    user_names = options.present? && options[:user_names] ? options[:user_names] : schedule.get_usernames
    user_names = user_names.present? ? "参加者： #{user_names}" : ""
    prop_names = options.present? && options[:prop_names] ? options[:prop_names] : schedule.get_propnames
    prop_names = prop_names.present? ? "施設： #{prop_names}" : ""

    tooltip_a = [title,
      place,
      memo,
      prop_names.present? ? inquire_to : "",
      public,
      user_names,
      prop_names.present? ? prop_names : ""
    ]
    tooltip = Gw.join(tooltip_a, is_ie ?  "\n" : '<br/>')
    tooltip = Gw.simple_strip_html_tags(tooltip, :exclude_tags=>'br/')
    return tooltip
  end

  def create_todo_tooltip( todo, is_ie = Gw.ie?(request) )
    tooltip_a = ["期限： #{Gw.datetime_to_date(todo.ed_at)}", "内容： #{todo.title}"]
    tooltip = Gw.join(tooltip_a, is_ie ?  "\n" : '<br/>')
    tooltip = Gw.simple_strip_html_tags(tooltip, :exclude_tags=>'br/')
    return tooltip
  end

  def show_week_one(schedule, week_add_day, schedule_id, user_id, options = {})
    if @schedule_settings[:view_schedule_title_display].to_i == 1
      class_str = "schedule-show-ellipsis"
      schedule_show_time = schedule.show_time_ellipsis(week_add_day)
    else
      class_str = "schedule-show-all"
      schedule_show_time = schedule.show_time(week_add_day)
    end

    if schedule.is_public_auth?(@is_gw_admin)
      if user_id.to_s == Site.user.id.to_s && schedule.remind_unseen?(schedule) && !request.env['PATH_INFO'].include?("schedule_props")
        new = "<span class='new'>new</span>"
      else
        new = nil
      end
      if @schedule_settings[:view_place_display] == '1' &&
          schedule.place.present?
        place = "<span class='place'>（#{schedule.place}）</span>"
      else
        place = nil
      end
html = <<HTML
<div title="#{create_schedule_tooltip(schedule, @ie, options)}" class="ind #{class_str}" id="#{schedule_id}">
  <a class="#{schedule.get_category_class}" href="/gw/schedules/#{schedule.id}/show_one">
    #{new}
    <span>#{schedule_show_time}</span>
    <span class="title">#{schedule.title}</span>
    #{place}
  </a>
</div>
HTML
    else
      t = schedule.show_time(week_add_day)
      if @ie
        title = "#{t} [予定有り]"
      else
        title = "<span>#{t} [予定有り]</span>"
      end
html = <<HTML
<div title="#{title}" id="#{schedule_id}" class="ind #{class_str}">
  <a class="category0"><span>#{schedule_show_time}</span>
  <span class="title">[予定有り]</span></a>
</div>
HTML
    end
    html.html_safe
  end

end
