#encoding:utf-8
module Gwcircular::DocsHelper

  def gwcircular_attachments_form(form, item, mode=nil)
    form_id = '' if form_id.blank?
    return render(:partial => 'gwcircular/admin/tool/attachments/form', :locals => {:f => form, :item => item, :mode => mode})
  end

  def readers_table(title, objects, col, s_class)
    ret = ''
    ret += %Q[<table class="#{s_class}">]
    ret += %Q[<tr><th colspan="#{col}">#{title}</th></tr>]
    i=0
    s_table = ''
    for object in objects
      if col <= i
        i = 0
        s_table += '</tr>'
      end
      s_table += '<tr>' if i == 0
      s_table += %Q[<td style="width: auto;">・#{object[2]}&nbsp;</td>]
      i += 1
    end
    unless i == 0
      j = col - i
      for i in 1..j
        s_table += %Q[<td style="width: auto;"></td>]
      end
      s_table += '</tr>'
    end
    ret += s_table
    ret += '</table>'
    return ret
  end

  def open_mail_form(uri)
    uri = escape_javascript(uri)
    "openMailForm('#{uri}', '#{mail_form_style}');"
  end

  def mail_form_style
    "resizable=yes,scrollbars=yes"
  end

  def open_gwbbs_form(uri)
    uri = escape_javascript(uri)
    "openGwbbsForm('#{uri}', '#{gwbbs_form_style}');"
  end

  def gwbbs_form_style
    "resizable=yes,scrollbars=yes"
  end
end
