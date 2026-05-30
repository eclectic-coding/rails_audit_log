require "rails_helper"

RSpec.describe "RailsAuditLog dashboard", type: :request do
  describe "GET /audit (root)" do
    it "returns 200" do
      get "/audit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /audit/audit_log_entries" do
    it "returns 200" do
      get "/audit/audit_log_entries"
      expect(response).to have_http_status(:ok)
    end

    it "shows the entry count" do
      Post.create!(title: "Hello")
      get "/audit/audit_log_entries"
      expect(response.body).to include("1 entry")
    end

    it "shows an empty state when there are no entries" do
      get "/audit/audit_log_entries"
      expect(response.body).to include("No audit entries found.")
    end

    it "renders a table row for each entry on the page" do
      3.times { |i| Post.create!(title: "Post #{i}") }
      get "/audit/audit_log_entries"
      expect(response.body).to include("create").and include("Post")
    end

    it "wraps the table in a turbo frame" do
      get "/audit/audit_log_entries"
      expect(response.body).to include('id="ral-entries"')
    end

    context "with more than page_size entries" do
      before do
        (RailsAuditLog.page_size + 2).times do |i|
          RailsAuditLog::AuditLogEntry.create!(
            event: "create", item_type: "Post", item_id: i + 1,
            object_changes: { "title" => [nil, "Post #{i}"] }
          )
        end
      end

      it "shows pagy pagination nav" do
        get "/audit/audit_log_entries"
        expect(response.body).to include('class="pagy series-nav"')
      end

      it "navigates to page 2" do
        get "/audit/audit_log_entries", params: { page: 2 }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('aria-current="page"')
      end
    end
  end

  describe "GET /audit/audit_log_entries filters" do
    before do
      user = User.create!(name: "Alice")
      RailsAuditLog.with_actor(user) do
        @post = Post.create!(title: "Hello")
        @post.update!(title: "Updated")
      end
      Post.create!(title: "Other post")
    end

    it "filters by event type" do
      get "/audit/audit_log_entries", params: { event: "update" }
      expect(response.body).to include("update")
      expect(response.body).not_to include("ral-badge--create")
    end

    it "ignores invalid event values" do
      get "/audit/audit_log_entries", params: { event: "DROP TABLE" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ral-badge")
    end

    it "filters by resource class" do
      get "/audit/audit_log_entries", params: { item_type: "Post" }
      expect(response.body).to include("Post")
      expect(response).to have_http_status(:ok)
    end

    it "filters by actor name" do
      get "/audit/audit_log_entries", params: { q: "Alice" }
      expect(response.body).to include("Alice")
      expect(response).to have_http_status(:ok)
    end

    it "filters by period" do
      get "/audit/audit_log_entries", params: { period: "1h" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ral-period-btn--active")
    end

    it "shows the Clear link when filters are active" do
      get "/audit/audit_log_entries", params: { event: "create" }
      expect(response.body).to include("Clear")
    end

    it "does not show the Clear link when no filters are active" do
      get "/audit/audit_log_entries"
      expect(response.body).not_to include(">Clear<")
    end

    it "renders the filter form" do
      get "/audit/audit_log_entries"
      expect(response.body).to include("ral-filters")
    end
  end

  describe "GET /audit/resources/:item_type/:item_id" do
    let!(:post)  { Post.create!(title: "Hello") }
    let!(:other) { Post.create!(title: "Other") }

    it "returns 200" do
      get "/audit/resources/Post/#{post.id}"
      expect(response).to have_http_status(:ok)
    end

    it "shows only entries for the specified record" do
      get "/audit/resources/Post/#{post.id}"
      expect(response.body).to include("Post ##{post.id}")
      expect(response.body).not_to include("Post ##{other.id}")
    end

    it "shows the entry count for the record" do
      post.update!(title: "Updated")
      get "/audit/resources/Post/#{post.id}"
      expect(response.body).to include("2 entries")
    end

    it "renders a diff table for each entry" do
      get "/audit/resources/Post/#{post.id}"
      expect(response.body).to include("ral-diff")
    end

    it "wraps entries in a turbo frame" do
      get "/audit/resources/Post/#{post.id}"
      expect(response.body).to include('id="ral-resource-entries"')
    end

    it "shows an empty state when the record has no entries" do
      get "/audit/resources/Post/0"
      expect(response.body).to include("No audit entries for this record.")
    end
  end

  describe "GET /audit/audit_log_entries/:id" do
    let!(:entry) { Post.create!(title: "Hello").audit_log_entries.first }

    it "returns 200" do
      get "/audit/audit_log_entries/#{entry.id}"
      expect(response).to have_http_status(:ok)
    end

    it "shows entry metadata" do
      get "/audit/audit_log_entries/#{entry.id}"
      expect(response.body).to include("create")
      expect(response.body).to include("Post")
    end

    it "renders the diff table" do
      get "/audit/audit_log_entries/#{entry.id}"
      expect(response.body).to include("ral-diff")
    end

    it "links to the resource timeline" do
      get "/audit/audit_log_entries/#{entry.id}"
      expect(response.body).to include("resources/Post/#{entry.item_id}")
    end

    it "shows next entry link when one exists" do
      post = Post.find(entry.item_id)
      post.update!(title: "Updated")
      get "/audit/audit_log_entries/#{entry.id}"
      expect(response.body).to include("Next →")
    end
  end
end
