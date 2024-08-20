require 'spec_helper'

describe Cms::NodeImporter, dbscope: :example do
  let!(:site) { cms_site }
  let!(:user) { cms_user }
  let!(:node) { nil }

  let!(:csv_path) { "#{Rails.root}/spec/fixtures/cms/node/import/image_map.csv" }
  let!(:csv_file) { Fs::UploadedFile.create_from_file(csv_path) }
  let!(:ss_file) { create(:ss_file, site: site, user: user, in_file: csv_file) }

  def find_node(filename)
    Cms::Node.site(site).where(filename: filename).first
  end

  context "image_map nodes" do
    it "#import" do
      # Check initial node count
      expect(Cms::Node.count).to eq(0)

      importer = described_class.new(site, node, user)
      importer.import(ss_file)

      # Check the node count after import
      csv = CSV.read(csv_path, headers: true)
      expect(Cms::Node.count).to eq(0) # it will not save the node because no image is present

    end
  end
end
