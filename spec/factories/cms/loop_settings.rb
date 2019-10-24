FactoryBot.define do
  factory :cms_loop_setting, class: Cms::LoopSetting do
    transient do
      site nil
    end

    cur_site { site || cms_site }
    name { "name-#{unique_id}" }
    description { "description-#{unique_id}" }
    html { "html-#{unique_id}" }
  end
end
