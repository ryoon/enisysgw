# -*- encoding: utf-8 -*-
class Gwbbs::Script::Annual

  def self.renew
    p "掲示板年次切替所属情報更新 開始:#{Time.now}."
    renew_adms
    renew_admingrps_json
    renew_roles
    renew_editors_json
    renew_readers_json
    renew_docs_section_code
    renew_section_bbs_title
    renew_dsp_admin_name
    renew_create_section
    p "掲示板年次切替所属情報更新 終了:#{Time.now}."
  end

  def self.renew_adms
    p "renew_adms 開始:#{Time.now}."
    sql  = 'SELECT group_id, group_code'
    sql += " FROM gwbbs_adms"
    sql += " GROUP BY group_id, group_code"
    sql += " ORDER BY group_id, group_code"
    adms = Gwbbs::Adm.find_by_sql(sql)
    for adm in adms
      item = Gwboard::RenewalGroup.new
      item.and :present_group_id, adm.group_id
      item.and :present_group_code, adm.group_code
      group = item.find(:first, :order=> 'present_group_id, present_group_code')
      next if group.blank?

      update_fields="group_id=#{group.incoming_group_id}, group_code='#{group.incoming_group_code}',group_name='#{group.incoming_group_name}'"
      sql_where = "group_id=#{adm.group_id} AND group_code='#{adm.group_code}'"
      Gwbbs::Adm.update_all(update_fields, sql_where)
      p "#{adm.group_id}, #{adm.group_code}, #{update_fields}, #{Time.now}."
    end
    p "renew_adms 終了:#{Time.now}."
  end

  def self.renew_admingrps_json
    p "renew_admingrps_json 開始:#{Time.now}."

    title = Gwbbs::Control.new
    titles = title.find(:all, :order=>'id')

    for title in titles
      groups = JsonParser.new.parse(title.admingrps_json)
      is_update = false
      groups.each do |group|
        renewal = Gwboard::RenewalGroup.new
        renewal.and :present_group_id, group[1]
        renewal.and :present_group_code, group[0]
        if item = renewal.find(:first)
          group[0] = item.incoming_group_code
          group[1] = item.incoming_group_id.to_s
          group[2] = item.incoming_group_name
          is_update = true
        end
      end
      if is_update
        groups.uniq!
        update_field = "admingrps_json='#{JsonBuilder.new.build(groups)}'"
        Gwbbs::Control.update_all(update_field, "id=#{title.id}")
        p "#{title.id}, #{update_field}, #{Time.now}."
      end
    end
    p "renew_admingrps_json 終了:#{Time.now}."
  end

  def self.renew_roles
    p "renew_roles 開始:#{Time.now}."

    sql  = 'SELECT group_id, group_code'
    sql += " FROM gwbbs_roles"
    sql += " GROUP BY group_id, group_code"
    sql += " ORDER BY group_id, group_code"
    roles = Gwbbs::Role.find_by_sql(sql)
    for role in roles
      next if role.group_id.blank?
      next if role.group_id == 0

      item = Gwboard::RenewalGroup.new
      item.and :present_group_id, role.group_id
      item.and :present_group_code, role.group_code
      group = item.find(:first, :order=> 'present_group_id, present_group_code')
      next if group.blank?

      update_fields="group_id=#{group.incoming_group_id}, group_code='#{group.incoming_group_code}',group_name='#{group.incoming_group_name}'"
      sql_where = "group_id=#{role.group_id} AND group_code='#{role.group_code}'"
      Gwbbs::Role.update_all(update_fields, sql_where)
      p "#{role.group_id}, #{role.group_code}, #{update_fields}, #{Time.now}."
    end
    p "renew_roles 終了:#{Time.now}."
  end

  def self.renew_editors_json
    p "renew_editors_json 開始:#{Time.now}."

    title = Gwbbs::Control.new
    titles = title.find(:all, :order=>'id')

    for title in titles
      groups = JsonParser.new.parse(title.editors_json)
      is_update = false
      groups.each_with_index do |group,idx|
        renewal = Gwboard::RenewalGroup.new
        renewal.and :present_group_id, group[1]
        renewal.and :present_group_code, group[0]
        if item = renewal.find(:first)
          group[0] = item.incoming_group_code
          group[1] = item.incoming_group_id.to_s
          group[2] = item.incoming_group_name
          is_update = true
        end
      end
      if is_update
        groups.uniq!
        update_field = "editors_json='#{JsonBuilder.new.build(groups)}'"
        Gwbbs::Control.update_all(update_field, "id=#{title.id}")
        p "#{title.id}, #{update_field}, #{Time.now}."
      end
    end
    p "renew_editors_json 終了:#{Time.now}."
  end

  def self.renew_readers_json
    p "renew_readers_json 開始:#{Time.now}."

    title = Gwbbs::Control.new
    titles = title.find(:all, :order=>'id')

    for title in titles
      groups = JsonParser.new.parse(title.readers_json)
      is_update = false
      groups.each do |group|
        renewal = Gwboard::RenewalGroup.new
        renewal.and :present_group_id, group[1]
        renewal.and :present_group_code, group[0]
        if item = renewal.find(:first)
          group[0] = item.incoming_group_code
          group[1] = item.incoming_group_id.to_s
          group[2] = item.incoming_group_name
          is_update = true
        end
      end
      if is_update
        groups.uniq!
        update_field = "readers_json='#{JsonBuilder.new.build(groups)}'"
        Gwbbs::Control.update_all(update_field, "id=#{title.id}")
        p "#{title.id}, #{update_field}, #{Time.now}."
      end
    end
    p "renew_readers_json 終了:#{Time.now}."
  end

  def self.renew_docs_section_code
    p "renew_docs_section_code 開始:#{Time.now}."

    items = Gwbbs::Control.find(:all, :order=>'id')
    for @title in items
      begin
        doc_item = db_alias(Gwbbs::Doc)
        sql  = 'SELECT section_code FROM gwbbs_docs GROUP BY section_code ORDER BY section_code'
        docs = doc_item.find_by_sql(sql)
        for doc in docs
          next if doc.section_code.blank?

          group = Gwboard::RenewalGroup.find_by_present_group_code(doc.section_code)
          next if group.blank?

          update_fields = "section_code='#{group.incoming_group_code}', section_name='#{group.incoming_group_code}#{group.incoming_group_name}'"
          doc_item.update_all(update_fields, "section_code='#{doc.section_code}'")
          p "#{@title.dbname}, #{doc.section_code}, #{update_fields}, #{Time.now}."
        end
      rescue => ex
        p "ERROR: #{@title.dbname} :#{ex.message}."
      end
      Gwbbs::Doc.remove_connection
    end
    p "renew_docs_section_code 終了:#{Time.now}."
  end

  def self.renew_section_bbs_title
    item = Gwbbs::Control.new
    item.and :create_section, 'is not', nil
    items = item.find(:all, :order=> 'id')
    for bbs in items
      group = Gwboard::RenewalGroup.find_by_present_group_code(bbs.create_section)
      next if group.blank?

        update_field = "title='#{group.incoming_group_name}掲示板'"
        Gwbbs::Control.update_all(update_field, "id='#{bbs.id}'")
      p "#{bbs.id}, #{bbs.create_section}, #{update_field}, #{Time.now}."
    end

  end

  def self.renew_dsp_admin_name
    title = Gwbbs::Control.new
    titles = title.find(:all, :order=> 'id')
    for title in titles
      group = Gwboard::RenewalGroup.find_by_present_group_name(title.dsp_admin_name)
      next if group.blank?

      update_field = "dsp_admin_name='#{group.incoming_group_name}'"
      Gwbbs::Control.update_all(update_field, "id='#{title.id}'")
      p "#{title.id}, #{title.create_section}, #{update_field}, #{Time.now}."
    end
  end

  def self.renew_create_section
    p "renew_dsp_admin_name 開始:#{Time.now}."

    item = Gwbbs::Control.new
    item.and :create_section, 'is not', nil
    items = item.find(:all, :order=> 'id')
    for bbs in items
      group = Gwboard::RenewalGroup.find_by_present_group_code(bbs.create_section)
      next if group.blank?

      update_field = "create_section='#{group.incoming_group_code}'"
      Gwbbs::Control.update_all(update_field, "id='#{bbs.id}'")
      p "#{bbs.id}, #{bbs.create_section}, #{update_field}, #{Time.now}."
    end

    p "renew_dsp_admin_name 終了:#{Time.now}."
  end

  def self.db_alias(item)
    cnn = item.establish_connection
    cnn.spec.config[:database] = @title.dbname.to_s
    Gwboard::CommonDb.establish_connection(cnn.spec.config)
    return item
  end

end
