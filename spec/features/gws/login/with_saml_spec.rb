require 'spec_helper'

describe "gws_login", type: :feature, dbscope: :example, js: true do
  let!(:site) { gws_site }
  let(:name) { unique_id }
  let(:filename) { unique_id }
  let(:metadata_file) { "#{Rails.root}/spec/fixtures/sys/auth/metadata-1.xml" }

  before do
    Fs::UploadedFile.create_from_file(metadata_file, basename: "spec") do |file|
      saml = Sys::Auth::Saml.new
      saml.name = name
      saml.filename = filename
      saml.in_metadata = file
      saml.force_authn_state = "enabled"
      saml.save!
    end

    # saml.sso_url = "#{site.url}/samling/samling.html"
    # saml.slo_url = "#{site.url}/samling/samling.html"
    # saml.save!

    presence = user.user_presence(site)
    presence.sync_available_state = "enabled"
    presence.sync_unavailable_state = "enabled"
    presence.save!

    # SAML Mock Server(https) からシラサギ (http) へ post する際、Chrome v110 からセキュリティエラーが発生するようになった。
    # セキュリティエラーを防ぐため、明示的にシラサギ URL を http://0.0.0.0 ではなく http://127.0.0.1 へ変更する
    @save_app_host = Capybara.app_host
    Capybara.app_host = "http://127.0.0.1:#{Capybara.current_session.server.port}"
  end

  after do
    Capybara.app_host = @save_app_host
  end

  context "with saml" do
    shared_examples "saml login is" do
      it do
        visit gws_login_path(site: site)
        click_on name

        #
        # blow form is outside of SHIRASAGI. it's sampling (https://capriza.github.io/samling/samling.html)
        #
        within "form#samlProps" do
          fill_in "nameIdentifier", with: user.email
          click_on "Next"
        end

        within "form#samlResponseForm" do
          click_on "Post Response!"
        end

        #
        # Now back to SHIRASAGI
        #

        # confirm a user has been logged-in
        expect(page).to have_css("nav.user .user-name", text: user.name)
        # confirm gws_portal is shown to user
        expect(page).to have_css(".portlets .portlet-item")

        presence = Gws::User.find(user.id).user_presence(site)
        expect(presence.state).to eq "available"

        if user.type_sso?
          within ".user-navigation" do
            wait_event_to_fire("turbo:frame-load") { click_on user.name }
            expect(page).to have_no_link I18n.t("ss.logout", locale: user.lang)
          end
        else
          # do logout
          within ".user-navigation" do
            wait_event_to_fire("turbo:frame-load") { click_on user.name }
            click_on I18n.t("ss.logout", locale: user.lang)
          end

          # confirm a login form has been shown
          expect(page).to have_css(".login-box", text: I18n.t("ss.login", locale: I18n.default_locale))
          expect(page).to have_css("li", text: name)
          # and confirm browser back to gws_login
          expect(current_path).to eq gws_login_path(site: site)

          presence.reload
          expect(presence.state).to eq "unavailable"
        end
      end
    end

    context "with sns user" do
      let!(:user) { gws_user }
      it_behaves_like "saml login is"
    end

    context "with ldap user" do
      let!(:user) do
        create :gws_ldap_user2, organization: site, group_ids: gws_user.group_ids, gws_role_ids: gws_user.gws_role_ids
      end
      it_behaves_like "saml login is"
    end

    context "with sso user" do
      let!(:user) do
        create :gws_sso_user, organization: site, group_ids: gws_user.group_ids, gws_role_ids: gws_user.gws_role_ids
      end
      it_behaves_like "saml login is"
    end
  end
end
