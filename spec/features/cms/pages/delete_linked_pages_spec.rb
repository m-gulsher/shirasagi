require 'spec_helper'

describe "cms_delete_linked_pages", type: :feature, dbscope: :example, js: true do
  subject(:site) { cms_site }
  let!(:node) { create :article_node_page, st_form_ids: [1].map { |i| send("form#{i}").id } }
  let(:index_path) { article_pages_path site.id, node }
  let!(:form1) { create(:cms_form, cur_site: cms_site, state: 'public', sub_type: 'static') }
  let!(:column1) { create(:cms_column_free, cur_site: site, cur_form: form1, order: 1) }
  let!(:column2) { create(:cms_column_free, cur_site: site, cur_form: form1, order: 2) }
  let(:ss_file) { create_once :ss_file, user: cms_user }
  
  let!(:page1) do
    create(
      :article_page, cur_node: node, form: form1, name: "[TEST]page1",
      column_values: [ column1.value_type.new(column: column1, value: "test", file_ids: [ss_file.id]) ]
    )
  end

  let!(:page2) do
    create(
      :article_page, cur_node: node, form: form1, name: "[TEST]page2",
      column_values: [ column2.value_type.new(column: column2, value: "test", contains_urls: [ss_file.url]) ]
    )
  end

  before do 
    login_cms_user
    page2.set(form_contains_urls: [ss_file.url])
    page2.column_values.first.set(contains_urls: [ss_file.url])
    page2.reload
  end

  it "abc" do 
    visit index_path
    expect(page).to have_css(".flex-list-head")
    expect(page).to have_css("input[type='checkbox'][value='#{page1.id}']")
    expect(page).to have_css("input[type='checkbox'][value='#{page2.id}']")
    find("input[type='checkbox'][value='#{page1.id}']").click
    find("input[type='checkbox'][value='#{page2.id}']").click
    expect(find("input[type='checkbox'][value='#{page1.id}']")).to be_checked
    expect(find("input[type='checkbox'][value='#{page2.id}']")).to be_checked
    
    find('.destroy-all').click
    wait_for_js_ready

    expect(page).to have_css("input[type='checkbox'][value='#{page2.id}'][checked='checked']")
    expect(page).to_not have_css("input[type='checkbox'][value='#{page1.id}'][checked='checked']")
  end
end
