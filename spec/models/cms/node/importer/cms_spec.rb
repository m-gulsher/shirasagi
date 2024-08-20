require 'spec_helper'

describe Cms::NodeImporter, dbscope: :example do
  let!(:site) { cms_site }
  let!(:user) { cms_user }
  let!(:node) { nil }

  let!(:group1) { create :ss_group, name: "シラサギ市", order: 10 }
  let!(:group2) { create :ss_group, name: "シラサギ市/企画政策部", order: 20 }
  let!(:group3) { create :ss_group, name: "シラサギ市/企画政策部/政策課", order: 30 }
  let!(:group4) { create :ss_group, name: "シラサギ市/企画政策部/広報課", order: 40 }
  let!(:group5) { create :ss_group, name: "シラサギ市/危機管理部", order: 50 }
  let!(:group6) { create :ss_group, name: "シラサギ市/危機管理部/管理課", order: 60 }
  let!(:group7) { create :ss_group, name: "シラサギ市/危機管理部/防災課", order: 70 }

  let!(:cate1) { create :category_node_page, name: "よくある質問", filename: "faq" }
  let!(:cate2) { create :category_node_page, name: "くらしのガイド", filename: "guide" }
  let!(:cate3) { create :category_node_page, name: "観光・文化・スポーツ", filename: "kanko" }
  let!(:cate4) { create :category_node_page, name: "健康・福祉", filename: "kenko" }
  let!(:cate5) { create :category_node_page, name: "子育て・教育", filename: "kosodate" }
  let!(:cate6) { create :category_node_page, name: "くらし・手続き", filename: "kurashi" }
  let!(:cate7) { create :category_node_page, name: "お知らせ", filename: "oshirase" }
  let!(:cate8) { create :category_node_page, name: "産業・仕事", filename: "sangyo" }
  let!(:cate9) { create :category_node_page, name: "市政情報", filename: "shisei" }
  let!(:cate10) { create :category_node_page, name: "街の話題", filename: "topics" }
  let!(:cate11) { create :category_node_page, name: "緊急情報", filename: "urgency" }

  let!(:csv_path) { "#{Rails.root}/spec/fixtures/cms/node/import/cms.csv" }
  let!(:csv_file) { Fs::UploadedFile.create_from_file(csv_path) }
  let!(:ss_file) { create(:ss_file, site: site, user: user, in_file: csv_file) }

  before do
    site.group_ids += [group1.id]
    site.update!
  end

  context "cms nodes" do
    it "#import" do
      # Check initial node count
      expect(Cms::Node::Base.count).to eq(0)

      importer = described_class.new(site, node, user)
      importer.import(ss_file)

      # Check the node count after import
      csv = CSV.read(csv_path, headers: true)
      expect(Cms::Node::Base.count).to eq(csv.size)

      Cms::Node::Base.each_with_index do |node, index|
        row = csv[index].to_hash

        expect(row["﻿ファイル名"]).to eq node.basename
        expect(row["フォルダー属性"]).to eq node.route
        expect(row["タイトル"]).to eq node.name
        expect(row["一覧用タイトル"]).to eq node.index_name
        expect(row["並び順"]).to eq node.order.to_s
        expect(row["ショートカット"]).to eq node.label(:shortcut)
        expect(row["既定のモジュール"]).to eq node.label(:view_route)

        # meta addon (some nodes are included it)
        if node.class.include?(Cms::Addon::Meta)
          expect(row["キーワード"]).to eq node.keywords.join("\n").presence
          expect(row["概要"]).to eq node.description
          expect(row["サマリー"]).to eq node.summary_html
        end

        # list addon (some nodes are included it)
        if node.class.include?(Cms::Addon::List::Model)
          expect(row["検索条件(URL)"]).to eq node.conditions.join("\n").presence
          expect(row["リスト並び順"]).to eq node.label(:sort)
          expect(row["表示件数"]).to eq node.limit.to_s
          expect(row["NEWマーク期間"]).to eq node.new_days.to_s
          expect(row["ループHTML形式"]).to eq node.label(:loop_format)
          expect(row["上部HTML"]).to eq node.upper_html
          expect(row["ループHTML(SHIRASAGI形式)"]).to eq node.loop_html
          expect(row["下部HTML"]).to eq node.lower_html
          expect(row["ループHTML(Liquid形式)"]).to eq node.loop_liquid
          expect(row["ページ未検出時表示"]).to eq node.label(:no_items_display_state)
          expect(row["代替HTML"]).to eq node.substitute_html
        end

        # category addon
        expect(row["カテゴリー設定"]).to eq node.st_categories.map { |cate| "#{cate.name} (#{cate.filename})" }.join("\n").presence

        # release addon
        expect(row["公開日時種別"]).to eq node.label(:released_type)
        expect(row["ステータス"]).to eq node.label(:state)

        # cms groups addon
        expect(row["管理グループ"]).to eq node.groups.map(&:name).join("\n").presence
      end
    end
  end
end
