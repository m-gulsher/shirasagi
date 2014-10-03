# coding: utf-8
require 'spec_helper'

describe "cms_generate_pages" do
  subject(:site) { cms_site }
  subject(:node) { create_once :cms_node_page, name: "cms" }
  subject(:index_path) { node_generate_pages_path site.host, node }

  it "without login" do
    visit index_path
    expect(current_path).to eq sns_login_path
  end

  it "without auth" do
    login_ss_user
    visit index_path
    expect(status_code).to eq 403
  end

  context "with auth" do
    before { login_cms_user }

    it "#index" do
      visit index_path
      expect(current_path).not_to eq sns_login_path
    end
  end
end
