# CSV
# app/models/gws/workflow/form/file_exporter.rb
# app/models/gws/workflow/file_enumerator.rb
class Gws::Workflow2::FileEnumerator < Enumerator
  def initialize(site, wf_files, encoding: "UTF-8", form: nil)
    @cur_user = SS.current_user
    @cur_site = site
    @wf_files = wf_files.dup
    @encoding = encoding

    super() do |yielder|
      load_forms
      build_term_handlers

      yielder << bom + encode(headers.to_csv)
      @wf_files.each do |wf_file|
        enum_comment(yielder, wf_file)
      end
    end
  end

  private

  def load_forms
    if @wf_files.is_a?(Mongoid::Criteria)
      form_ids = @wf_files.pluck(:form_id).uniq
    else
      form_ids = @wf_files.map { |wf_file| wf_file.form_id }.uniq
    end

    @base_form_use = form_ids.include?(nil)
    @forms = Gws::Workflow2::Form::Base.site(@cur_site).in(id: form_ids.compact).order_by(order: 1, created: 1)
    # load all forms in memory for performance
    @forms = @forms.to_a
  end

  def build_term_handlers
    @handlers = []

    %i[user_id user_name user_group user_email].each do |key|
      @handlers << {
        name: I18n.t("gws/workflow2.table.gws/workflow2/file.#{key}"), handler: method("to_#{key}"), type: :base
      }
    end

    @handlers << { name: Gws::Workflow2::File.t(:name), handler: method(:to_name), type: :base }

    if @base_form_use
      @handlers << { name: Gws::Workflow2::File.t(:html), handler: method(:to_html), type: :base }
      @handlers << { name: Gws::Workflow2::File.t(:file_ids), handler: method(:to_files), type: :base }
    end

    @handlers << { name: I18n.t("gws/workflow2.table.gws/workflow2/file.requested"), handler: method(:to_requested), type: :base }
    @handlers << { name: Gws::Workflow2::File.t(:workflow_comment), handler: method(:to_workflow_comment), type: :base }
    @handlers << { name: I18n.t("workflow.csv.approvers_or_circulations"), handler: method(:to_step_no), type: :step }
    @handlers << { name: nil, handler: method(:to_required_count), type: :step }
    @handlers << { name: nil, handler: method(:to_step_user_name), type: :step }
    @handlers << { name: nil, handler: method(:to_step_state), type: :step }
    @handlers << { name: nil, handler: method(:to_step_comment), type: :step }
    @handlers << { name: Gws::Workflow2::File.t(:workflow_state), handler: method(:to_workflow_state), type: :base }
    @handlers << { name: Gws::Workflow2::File.t(:updated), handler: method(:to_updated), type: :base }

    @forms.each do |form|
      form.columns.order_by(order: 1).each do |column|
        next if column._type == 'Gws::Column::Title'
        next if column._type == 'Gws::Column::Section'
        @handlers << {
          name: "#{form.name}/#{column.name}",
          handler: method(:to_column_value).curry.call(form, column),
          type: :base
        }
      end
    end

    %i[agent_id agent_name agent_group agent_email].each do |key|
      @handlers << {
        name: I18n.t("gws/workflow2.table.gws/workflow2/file.#{key}"), handler: method("to_#{key}"), type: :base
      }
    end
  end

  # rubocop:disable Rails::Pluck
  def headers
    @handlers.map { |handler| handler[:name] }
  end
  # rubocop:enable Rails::Pluck

  def enum_comment(yielder, wf_file)
    yielder << encode(base_infos(wf_file).to_csv)

    wf_file.workflow_levels.each do |level|
      wf_file.workflow_approvers_at(level).each do |workflow_approver|
        yielder << encode(approver_info(wf_file, level, workflow_approver).to_csv)
      end
    end

    1.upto(Gws::Workflow2::Route::MAX_CIRCULATIONS).each do |level|
      wf_file.workflow_circulations_at(level).each do |workflow_circulation|
        yielder << encode(circulation_info(wf_file, level, workflow_circulation).to_csv)
      end
    end
  end

  def base_infos(wf_file)
    @handlers.map do |handler|
      if handler[:type] == :base
        handler[:handler].call(wf_file)
      else
        nil
      end
    end
  end

  def approver_info(wf_file, level, workflow_approver)
    @handlers.map do |handler|
      if handler[:type] == :step
        handler[:handler].call(wf_file, :approver, level, workflow_approver)
      else
        nil
      end
    end
  end

  def circulation_info(wf_file, level, workflow_circulation)
    @handlers.map do |handler|
      if handler[:type] == :step
        handler[:handler].call(wf_file, :circulation, level, workflow_circulation)
      else
        nil
      end
    end
  end

  # workflow_user_custom_data

  def to_user_id(item)
    item.workflow_user_id
  end

  def to_user_name(item)
    find_workflow_user_custom_data_value(item, "name")
  end

  def to_user_group(item)
    find_workflow_user_custom_data_value(item, "section_name")
  end

  def to_user_email(item)
    find_workflow_user_custom_data_value(item, "email")
  end

  def find_workflow_user_custom_data_value(item, name)
    return if item.workflow_user_custom_data.blank?

    custom_data = item.workflow_user_custom_data.find { |data| data["name"] == name }
    return unless custom_data

    custom_data["value"]
  end

  # workflow_agent_custom_data

  def to_agent_id(item)
    item.workflow_agent_id
  end

  def to_agent_name(item)
    find_workflow_agent_custom_data_value(item, "name")
  end

  def to_agent_group(item)
    find_workflow_agent_custom_data_value(item, "section_name")
  end

  def to_agent_email(item)
    find_workflow_agent_custom_data_value(item, "email")
  end

  def find_workflow_agent_custom_data_value(item, name)
    return if item.workflow_agent_custom_data.blank?

    custom_data = item.workflow_agent_custom_data.find { |data| data["name"] == name }
    return unless custom_data

    custom_data["value"]
  end

  def to_requested(item)
    item.requested ? item.requested.strftime("%Y/%m/%d %H:%M") : nil
  end

  def to_name(wf_file)
    wf_file.name
  end

  def to_html(wf_file)
    return nil if wf_file.form_id.present?

    wf_file.html
  end

  def to_files(wf_file)
    filenames = []

    SS::File.in(id: wf_file.file_ids).each do |file|
      filenames << file.humanized_name
    end

    filenames.join("\n")
  end

  def to_column_value(form, column, wf_file)
    return nil if form.id != wf_file.form_id

    column_value = wf_file.column_values.where(column_id: column.id).first
    return nil if column_value.blank?

    value = column_value.value
    value = "#{value}#{column_value.try(:concat_other_value)}" if column._type == 'Gws::Column::RadioButton'
    value
  end

  def to_request_user_name(wf_file)
    if wf_file.workflow_user.present?
      user_name = "#{wf_file.workflow_user.long_name}(#{wf_file.workflow_user.email})"
    else
      user_name = nil
    end
    return nil if user_name.blank?

    agent = wf_file.workflow_agent
    return user_name if agent.blank?

    agent_name = I18n.t(
      agent.email.blank? ? "agent_name" : "agent_name_with_email",
      scope: :workflow, long_name: agent.long_name, email: agent.email
    )
    user_name + agent_name
  end

  def to_workflow_state(wf_file)
    return nil if wf_file.workflow_state.blank?

    I18n.t("workflow.state.#{wf_file.workflow_state}")
  end

  def to_workflow_comment(wf_file)
    wf_file.workflow_comment
  end

  def to_updated(wf_file)
    I18n.l(wf_file.updated)
  end

  def to_step_no(wf_file, type, level, step_info)
    if type == :approver
      I18n.t('mongoid.attributes.workflow/model/route.level', level: level)
    else
      "#{I18n.t("workflow.circulation_step")} #{I18n.t('mongoid.attributes.workflow/model/route.level', level: level)}"
    end
  end

  def to_required_count(wf_file, type, level, step_info)
    return if type != :approver

    required_count = wf_file.workflow_required_counts[level - 1]
    if required_count
      I18n.t('workflow.required_count_label.minimum', required_count: required_count)
    else
      I18n.t('workflow.required_count_label.all')
    end
  end

  def to_step_user_name(wf_file, type, level, step_info)
    user_id = step_info[:user_id]
    user = SS::User.where(id: user_id).first

    if user
      if type == :approver && wf_file.route_my_group_alternate? && step_info == wf_file.workflow_approvers[1]
        I18n.t('gws/workflow.labels.approver_alternator') + "#{user.long_name}(#{user.email})"
      else
        "#{user.long_name}(#{user.email})"
      end
    else
      I18n.t("workflow.user_deleted")
    end
  end

  def to_step_state(wf_file, type, level, step_info)
    state = step_info[:state]
    if type == :approver
      created = step_info[:created].in_time_zone(@cur_user.timezone).strftime(" (%Y/%m/%d %H:%M)") rescue ''
      I18n.t("workflow.state.#{state}") + created
    else
      I18n.t("workflow.circulation_state.#{state}")
    end
  end

  def to_step_comment(wf_file, type, level, step_info)
    comment = step_info[:comment]
    file_ids = step_info[:file_ids]
    files = file_ids.present? ? SS::File.in(id: file_ids) : SS::File.none

    comments = []
    comments << comment if comment
    if files.present?
      files.each do |file|
        comments << file.humanized_name
      end
    end

    comments.join("\n")
  end

  def encode(str)
    return '' if str.blank?

    str = str.encode('CP932', invalid: :replace, undef: :replace) if @encoding == 'Shift_JIS'
    str
  end

  def bom
    return '' if @encoding == 'Shift_JIS'
    "\uFEFF"
  end
end
